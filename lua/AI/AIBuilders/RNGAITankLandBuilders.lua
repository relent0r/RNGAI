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

local LandAttackHeavyMode = function(self, aiBrain, builderManager)
    local myExtractorCount = aiBrain.BrainIntel.SelfThreat.AllyExtratorCount
    local totalMassMarkers = aiBrain.BrainIntel.SelfThreat.MassMarker
    if myExtractorCount > totalMassMarkers / 2 then
        --LOG('Enable Land Heavy Attack Queue')
        return 790
    else
        --LOG('Disable Land Heavy Attack Queue')
        return 0
    end
end

local LandAttackMode = function(self, aiBrain, builderManager)
    local myExtractorCount = aiBrain.BrainIntel.SelfThreat.AllyExtratorCount
    local totalMassMarkers = aiBrain.BrainIntel.SelfThreat.MassMarker
    if myExtractorCount < totalMassMarkers / 2 then
        --LOG('Enable Land Attack Queue')
        return 790
    else
        --LOG('Disable Land Attack Queue')
        return 0
    end
end

local LandEngMode = function(self, aiBrain, builderManager)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits <= 3 then
        --LOG('Setting T1 Queue to Eng')
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

local LandNoEngMode = function(self, aiBrain, builderManager)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits > 3 then
        --LOG('Setting T1 Queue to NoEng')
        return 750
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

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Small',
    BuildersType = 'FactoryBuilder',
    -- Opening Tank Build --
    --[[Builder {
        BuilderName = 'RNGAI Factory Tank Sera Small', -- Sera only because they don't get labs
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 900, -- After First Engie Group and scout
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 240 } }, -- don't build after 4 minutes
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },]]
    Builder {
        BuilderName = 'RNGAI Factory Initial Queue 10km Small',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild10k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 1000 } },
            { UCBC, 'LessThanGameTimeSeconds', { 270 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Initial Queue 5km Small',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild5k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 500 } },
            { UCBC, 'LessThanGameTimeSeconds', { 270 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land Attack Small',
        PlatoonTemplate = 'RNGAIT1LandAttackQueue',
        Priority = 750, -- After Second Engie Group
        PriorityFunction = LandEngMode,
        Restriction = 'TECH1',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 7, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability

            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land Attack NoEng Small',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueNoEng',
        Priority = 0, -- After Second Engie Group
        PriorityFunction = LandNoEngMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 7, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Attack Small',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 760,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Small',
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueue',
        Priority = 500, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 2, 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory T3 Amphib Attack Small',
        PlatoonTemplate = 'RNGAIT3AmphibAttackQueue',
        Priority = 550, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Large',
    BuildersType = 'FactoryBuilder',
    --[[Builder {
        BuilderName = 'RNGAI Factory Arty Sera Early Large', -- Sera cause floaty
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 900, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'LessThanGameTimeSeconds', { 300 } }, -- don't build after 4 minutes
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank Aeon Early Large', -- Aeon cause floaty
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 900, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'LessThanGameTimeSeconds', { 300 } }, -- don't build after 4 minutes
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },]]
    Builder {
        BuilderName = 'RNGAI Factory Arty Sera Large', -- Sera cause floaty
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 500, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.50, true}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 100, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank Aeon Large', -- Aeon cause floaty
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 500, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.50, true}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 100, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Initial Queue 20km',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild20k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 2000 } },
            { UCBC, 'LessThanGameTimeSeconds', { 300 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Initial Queue 40km',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild20k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 4000 } },
            { UCBC, 'LessThanGameTimeSeconds', { 300 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land Attack Large',
        PlatoonTemplate = 'RNGAIT1LandAttackQueue',
        Priority = 750, -- After Second Engie Group
        PriorityFunction = LandEngMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 7, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land Attack NoEng Large',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueNoEng',
        Priority = 0, -- After Second Engie Group
        PriorityFunction = LandNoEngMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 7, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability

            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Attack Large',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 760,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Large',
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueue',
        Priority = 0,
        PriorityFunction = AmphibNoSiegeMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 2, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50, true}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Large Siege',
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueueSiege',
        Priority = 0,
        PriorityFunction = AmphibSiegeMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 2, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50, true}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory T3 Amphib Attack Large',
        PlatoonTemplate = 'RNGAIT3AmphibAttackQueue',
        Priority = 0,
        PriorityFunction = AmphibNoSiegeMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory T3 Amphib Attack Large Siege',
        PlatoonTemplate = 'RNGAIT3AmphibAttackQueueSiege',
        Priority = 0,
        PriorityFunction = AmphibSiegeMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Reaction Tanks',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Tank Enemy Nearby',
        PlatoonTemplate = 'RNGAIT1LandResponse',
        Priority = 880,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.4, 0.5 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Tank Enemy Nearby',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.5, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Tank Enemy Nearby',
        PlatoonTemplate = 'RNGAIT3LandResponse',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land AA 2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Mobile AA Response',
        PlatoonTemplate = 'T1LandAA',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.LAND * categories.ANTIAIR } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile AA Response',
        PlatoonTemplate = 'T2LandAA',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.LAND * categories.ANTIAIR * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile AA Response',
        PlatoonTemplate = 'T3LandAA',
        Priority = 920,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.LAND * categories.ANTIAIR * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T3 AttackLandBuilder Small',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Attack T3 Small',
        PlatoonTemplate = 'RNGAIT3LandAttackQueue',
        Priority = 790,
        PriorityFunction = LandAttackMode,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Attack Heavy T3 Small',
        PlatoonTemplate = 'RNGAIT3LandAttackQueueHeavy',
        Priority = 0,
        PriorityFunction = LandAttackHeavyMode,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Arty ACUClose Small',
        PlatoonTemplate = 'T3LandArtillery',
        PriorityFunction = ACUClosePriority,
        Priority = 0,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.LAND * categories.MOBILE * categories.ARTILLERY * categories.TECH3 } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T3 AttackLandBuilder Large',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Attack T3 Large',
        PlatoonTemplate = 'RNGAIT3LandAttackQueue',
        Priority = 770,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Attack Heavy T3 Large',
        PlatoonTemplate = 'RNGAIT3LandAttackQueueHeavy',
        Priority = 0,
        PriorityFunction = LandAttackHeavyMode,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Arty ACUClose Large',
        PlatoonTemplate = 'T3LandArtillery',
        PriorityFunction = ACUClosePriority,
        Priority = 0,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.LAND * categories.MOBILE * categories.ARTILLERY * categories.TECH3 } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Large Unmarked',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Arty Sera Large Expansion', -- Sera cause floaty
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 500, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank Aeon Large Expansion', -- Aeon cause floaty
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 500, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land Expansion',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueExp',
        Priority = 700, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5, true}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Expansion',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 700,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Small Expansions',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Land Expansion Sml',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueExp',
        Priority = 700, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5, true}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Expansion Sml',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 700,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
}

-- Land Formers

BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders Expansion',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Mass Raid Expansions',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Small',                          -- Template Name.
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            LocationType = 'LocationType',
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 4900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = false,      
            AvoidClosestRadius = 100,
            UseFormation = 'AttackFormation',
            TargetSearchPriorities = { 
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {   
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
            },
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common Expansion Small',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            DistressRange = 100,
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon Expansion',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon',                          -- Template Name. 
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders Expansion Large',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1 Expansion Large',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 600,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) }}, -- stop building after we decent reach tech2 capability
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
            ThreatWeights = {
                IgnoreStrongerTargetsIfWeakerThan = 10, -- If the platoon is weaker than this threat level
                IgnoreStrongerTargetsRatio = 5, -- If platoon is weaker than the above threat then ignore stronger threats if stronger by this ratio. (so if they are 100?) 
                PrimaryThreatTargetType = 'StructuresNotMex', -- Primary type of threat to find targets
                SecondaryThreatTargetType = 'Land', -- Secondary type of threat to find targets
                SecondaryThreatWeight = 1,
                WeakAttackThreatWeight = 2, -- If the platoon is weaker than the target threat then decrease by this factor
                StrongAttackThreatWeight = 5, -- If the platoon is stronger than the target threat then increase by this factor
                VeryNearThreatWeight = 20, -- If the target is very close increase by this factor, default radius is 25
                NearThreatWeight = 10, -- If the target is close increase by this factor, default radius is 75
                MidThreatWeight = 5, -- If the target is mid range increase by this factor, default radius is 150
                FarThreatWeight = 1, -- if the target is far awat increase by this factor default radius is 300. There is also a VeryFar which is -1
                TargetCurrentEnemy = false, -- Take the current enemy into account when finding targets
                IgnoreCommanderStrength = false, -- Do we ignore the ACU's antisurface threat when picking an attack location
            },
        },         
    },
    Builder {
        BuilderName = 'RNGAI Mass Raid Expansions Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Small',                          -- Template Name.
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            LocationType = 'LocationType',
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 4900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = false,      
            AvoidClosestRadius = 100,
            UseFormation = 'AttackFormation',
            TargetSearchPriorities = { 
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {   
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
            },
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common Expansion Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            DistressRange = 100,
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon Expansion Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon Intelli',                          -- Template Name. 
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Response Formers',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Response BaseRestrictedArea',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 1000,                                                          -- Priority. 1000 is normal.
        InstanceCount = 6,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE - categories.SCOUT }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND - categories.ENGINEER - categories.INDIRECTFIRE} },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,                                               -- Searchradius for new target.
            DistressRange = 100,
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            LocationType = 'LocationType',
            Defensive = true,
            AttackEnemyStrength = 100,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchPriorities = {
                categories.MOBILE *categories.LAND,
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.EXPERIMENTAL,
                categories.MOBILE * categories.LAND * categories.INDIRECTFIRE,
                categories.MOBILE * categories.LAND * categories.DIRECTFIRE,
                categories.ENGINEER,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.ALLUNITS - categories.AIR - categories.NAVAL,
            },
            UseFormation = 'AttackFormation',
            ThreatSupport = 1,
        },
    },
    Builder {
        BuilderName = 'RNGAI Response BaseMilitary ANTIAIR Area',
        PlatoonTemplate = 'RNGAI Antiair Small',
        Priority = 1000,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseMilitaryArea, 'LocationType', 0, categories.MOBILE * categories.AIR * (categories.ANTIAIR + categories.BOMBER + categories.GROUNDATTACK) - categories.SCOUT }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.INDIRECTFIRE} },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,
            GetTargetsFromBase = true,
            RequireTransport = false,
            AggressiveMove = true,
            LocationType = 'LocationType',
            Defensive = true,
            AttackEnemyStrength = 200,                              
            TargetSearchPriorities = { 
                categories.MOBILE * categories.AIR
            },
            PrioritizedCategories = {   
                categories.MOBILE * categories.AIR * categories.GROUNDATTACK,
                categories.MOBILE * categories.AIR * categories.BOMBER,
                categories.MOBILE * categories.AIR,
            },
            UseFormation = 'None',
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Start Location Attack',
        PlatoonTemplate = 'RNGAI Guard Marker Small',
        Priority = 700,
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderConditions = {     
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER} },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER} },  	
            },
        BuilderData = {
            MarkerType = 'Start Location',            
            DistressRange = 100,
            SafeZone = true,
            MoveFirst = 'Threat',
            LocationType = 'LocationType',
            MoveNext = 'Threat',
            IgnoreFriendlyBase = true,
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 30,
            AggressiveMove = false,      
            AvoidClosestRadius = 50,
            GuardTimer = 10,              
            UseFormation = 'AttackFormation',
            ThreatSupport = 5,
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
            },
        },    
    },
    Builder {
        BuilderName = 'RNGAI Start Location Attack Transport',
        PlatoonTemplate = 'RNGAI Guard Marker Small',
        PriorityFunction = ACUClosePriority,
        Priority = 0,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER} },
            },
        BuilderData = {
            MarkerType = 'Start Location',            
            MoveFirst = 'Threat',
            MoveNext = 'Threat',
            IgnoreFriendlyBase = true,
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 30,
            LocationType = 'LocationType',
            AggressiveMove = true,      
            AvoidClosestRadius = 50,
            GuardTimer = 10,              
            UseFormation = 'AttackFormation',
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
            },
        },    
    },
    Builder {
        BuilderName = 'RNGAI Spam Early',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Early',                          -- Template Name. 
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 4,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 300 } }, -- don't build after 5 minutes
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Intelli',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        PlatoonAddBehaviors = { 'PlatoonRetreat' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            DistressRange = 100,
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            ThreatSupport = 5,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Intelli Amphib',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Amphib',                          -- Template Name. 
        Priority = 560,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * ( categories.AMPHIBIOUS + categories.HOVER ) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            ThreatSupport = 5,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam',                          -- Template Name. 
        Priority = 500,                                                          -- Priority. 1000 is normal.
        PlatoonAddBehaviors = { 'PlatoonRetreat' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 6, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
        },
        BuilderData = {
            UseFormation = 'None',
            DistressRange = 100,
            ThreatSupport = 2,
            LocationType = 'LocationType',
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.DIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            ThreatSupport = 2,
            LocationType = 'LocationType',
            },
    }, 
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 10,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.STRUCTURE * categories.DEFENSE,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.COMMAND,
                categories.MASSFABRICATION,
                categories.SHIELD,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            UseFormation = 'GrowthFormation',
            ThreatSupport = 5,
        },
    },
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 500,
        InstanceCount = 12,
        BuilderType = 'Any',
        BuilderConditions = {
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'MAIN', 3, categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) }}, -- stop building after we decent reach tech2 capability
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
            ThreatWeights = {
                IgnoreStrongerTargetsIfWeakerThan = 10, -- If the platoon is weaker than this threat level
                IgnoreStrongerTargetsRatio = 5, -- If platoon is weaker than the above threat then ignore stronger threats if stronger by this ratio. (so if they are 100?) 
                PrimaryThreatTargetType = 'StructuresNotMex', -- Primary type of threat to find targets
                SecondaryThreatTargetType = 'Land', -- Secondary type of threat to find targets
                SecondaryThreatWeight = 1,
                WeakAttackThreatWeight = 2, -- If the platoon is weaker than the target threat then decrease by this factor
                StrongAttackThreatWeight = 5, -- If the platoon is stronger than the target threat then increase by this factor
                VeryNearThreatWeight = 20, -- If the target is very close increase by this factor, default radius is 25
                NearThreatWeight = 10, -- If the target is close increase by this factor, default radius is 75
                MidThreatWeight = 5, -- If the target is mid range increase by this factor, default radius is 150
                FarThreatWeight = 1, -- if the target is far awat increase by this factor default radius is 300. There is also a VeryFar which is -1
                TargetCurrentEnemy = false, -- Take the current enemy into account when finding targets
                IgnoreCommanderStrength = false, -- Do we ignore the ACU's antisurface threat when picking an attack location
            },
        },         
    },
    Builder {
        BuilderName = 'RNGAI Attack AntiAir Structures',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack AA Structures',                          -- Template Name.
        Priority = 700,                                                          -- Priority. 1000 is normal.
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.LAND * categories.DIRECTFIRE * categories.MOBILE - categories.EXPERIMENTAL}},
            { MIBC, 'AirAttackModeCheck', {} },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.STRUCTURE * categories.ANTIAIR,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.STRUCTURE * categories.ANTIAIR,
                categories.MOBILE * categories.ANTIAIR,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.COMMAND,
                categories.MASSFABRICATION,
                categories.SHIELD,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            UseFormation = 'GrowthFormation',
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders Large',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Start Location Attack Large',
        PlatoonTemplate = 'RNGAI Guard Marker Small',
        Priority = 700,
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 3,
        BuilderType = 'Any',
        BuilderConditions = {     
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER} },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER} },  	
            },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            MarkerType = 'Start Location',            
            MoveFirst = 'Threat',
            SafeZone = true,
            MoveNext = 'Threat',
            IgnoreFriendlyBase = true,
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 30,
            AggressiveMove = false,      
            AvoidClosestRadius = 50,
            GuardTimer = 10,              
            UseFormation = 'AttackFormation',
            ThreatSupport = 5,
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
            },
        },    
    },
    Builder {
        BuilderName = 'RNGAI Spam Intelli Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        PlatoonAddBehaviors = { 'PlatoonRetreat' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            ThreatSupport = 5,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Intelli Amphib Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Amphib',                          -- Template Name. 
        Priority = 560,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * ( categories.AMPHIBIOUS + categories.HOVER ) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            PlatoonLimit = 15,
            ThreatSupport = 5,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.DIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            ThreatSupport = 2,
            },
    }, 
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2 Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 10,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,                                               -- Searchradius for new target.
            LocationType = 'LocationType',
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.STRUCTURE * categories.DEFENSE,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.COMMAND,
                categories.MASSFABRICATION,
                categories.SHIELD,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            UseFormation = 'GrowthFormation',
            ThreatSupport = 5,
        },
    },
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1 Large',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 500,
        InstanceCount = 12,
        BuilderType = 'Any',
        BuilderConditions = {
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'MAIN', 3, categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) }}, -- stop building after we decent reach tech2 capability
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
            ThreatWeights = {
                IgnoreStrongerTargetsIfWeakerThan = 10, -- If the platoon is weaker than this threat level
                IgnoreStrongerTargetsRatio = 5, -- If platoon is weaker than the above threat then ignore stronger threats if stronger by this ratio. (so if they are 100?) 
                PrimaryThreatTargetType = 'StructuresNotMex', -- Primary type of threat to find targets
                SecondaryThreatTargetType = 'Land', -- Secondary type of threat to find targets
                SecondaryThreatWeight = 1,
                WeakAttackThreatWeight = 2, -- If the platoon is weaker than the target threat then decrease by this factor
                StrongAttackThreatWeight = 5, -- If the platoon is stronger than the target threat then increase by this factor
                VeryNearThreatWeight = 20, -- If the target is very close increase by this factor, default radius is 25
                NearThreatWeight = 10, -- If the target is close increase by this factor, default radius is 75
                MidThreatWeight = 5, -- If the target is mid range increase by this factor, default radius is 150
                FarThreatWeight = 1, -- if the target is far awat increase by this factor default radius is 300. There is also a VeryFar which is -1
                TargetCurrentEnemy = false, -- Take the current enemy into account when finding targets
                IgnoreCommanderStrength = false, -- Do we ignore the ACU's antisurface threat when picking an attack location
            },
        },         
    },
    Builder {
        BuilderName = 'RNGAI Attack AntiAir Structures Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack AA Structures',                          -- Template Name.
        Priority = 700,                                                          -- Priority. 1000 is normal.
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.LAND * categories.DIRECTFIRE * categories.MOBILE - categories.EXPERIMENTAL}},
            { MIBC, 'AirAttackModeCheck', {} },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.STRUCTURE * categories.ANTIAIR,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE,
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.STRUCTURE * categories.ANTIAIR,
                categories.MOBILE * categories.ANTIAIR,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.COMMAND,
                categories.MASSFABRICATION,
                categories.SHIELD,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            UseFormation = 'GrowthFormation',
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Island Large FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Sera Arty Island',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Hover',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 4 }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Aeon Tanks Island',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Hover',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land Mass Raid',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Mass Raid Small',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Small',                          -- Template Name. 
        Priority = 700,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 4900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = false,      
            AvoidClosestRadius = 100,
            UseFormation = 'AttackFormation',
            TargetSearchPriorities = { 
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {   
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
            },
            },
            DistressRange = 100,
            DistressReactionTime = 8,
            ThreatSupport = 10,
    },
    Builder {
        BuilderName = 'RNGAI Mass Raid Medium',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Medium',                          -- Template Name.
        PlatoonAddBehaviors = { 'PlatoonRetreat' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = false,			-- Don't find high threat targets
            MaxThreatThreshold = 4900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 2000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = true,      
            AvoidClosestRadius = 50,
            UseFormation = 'NoFormation',
            TargetSearchPriorities = { 
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {   
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
            },
            },
    },
}
