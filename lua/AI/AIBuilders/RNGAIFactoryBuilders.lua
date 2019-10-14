--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Factory Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        BuilderConditions = {
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconTrend', { 0.3, 4.0 }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            -- Stop building T1 Factories after we have 6 T2
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 6, 'FACTORY LAND TECH2' }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 3, 'FACTORY LAND TECH1' }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Land T1',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        BuilderConditions = {
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconTrend', { 0.7, 4.0 }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            -- Stop building T1 Factories after we have 6 T2
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 6, 'FACTORY LAND TECH2' }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Air',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 High Pri',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        BuilderConditions = {
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconTrend', { 0.5, 4.0 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY AIR TECH1' }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        BuilderConditions = {
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconTrend', { 0.8, 8.0 }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 3, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
            -- disabled after using FactoryCapCheck { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.STRUCTURE * categories.FACTORY * categories.TECH1 * categories.AIR }},
            -- Respect UnitCap
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Staging Platform',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Air Staging 1',
        PlatoonTemplate = 'EngineerBuilder', -- Air Staging has been moved to T1 so don't need T2 engineers now.
        Priority = 900,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            -- Do we need additional conditions to build it ?
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.STRUCTURE * categories.ENERGYPRODUCTION } },
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrend', { 0.8, 8.0 }}, -- relative income
            { EBC, 'GreaterThanEconStorageRatio', { 0.30, 0.99}}, -- Ratio from 0 to 1. (1=100%)
            -- Don't build it if...
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            { MIBC, 'GreaterThanGameTime', { 480 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AirStagingPlatform',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 300,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 6, 'FACTORY TECH2, FACTORY TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { MIBC, 'GreaterThanGameTime', { 420 } },
            },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Upgrade Builders Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Expansion',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 200,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 6, 'FACTORY TECH2, FACTORY TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'FACTORY TECH2'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { MIBC, 'GreaterThanGameTime', { 420 } },
            },
        BuilderType = 'Any',
    },
}