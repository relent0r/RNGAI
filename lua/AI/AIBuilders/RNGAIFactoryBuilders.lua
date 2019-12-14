--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Factory Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'Factories' }},
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 0.9 }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            -- Stop building T1 Factories after we have 6 T2
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 6, 'FACTORY LAND TECH2' }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 3, 'FACTORY LAND TECH1' }},
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
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
        BuilderName = 'RNG Factory Builder Land T1 MainBase T2',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'Factories' }},
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.0 }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            -- Stop building T1 Factories after we have 6 T2
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 6, 'FACTORY LAND TECH2' }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 3, 'FACTORY LAND TECH1' }},
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
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
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'Factories' }},
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0 }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            -- Stop building T1 Factories after we have 6 T2
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 7, 'FACTORY LAND TECH2' }},
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
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'Factories' }},
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 0.9 }},
            { UCBC, 'FactoryLessAtLocation', { 'MAIN', 1, 'FACTORY AIR TECH1' }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'Factories' }},
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.15}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0 }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
            -- disabled after using FactoryCapCheck { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.STRUCTURE * categories.FACTORY * categories.TECH1 * categories.AIR }},
            -- Respect UnitCap
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 Main T2',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlattonDelay', { 'Factories' }},
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconStorageRatio', { 0.15, 0.15}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0 }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
            -- disabled after using FactoryCapCheck { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.STRUCTURE * categories.FACTORY * categories.TECH1 * categories.AIR }},
            -- Respect UnitCap
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = true,
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
            { EBC, 'GreaterThanEconTrend', { 0.4, 8.0 }}, -- relative income
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
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTime', { 420 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Support',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 650,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTime', { 420 } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) * categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTime', { 420 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'FACTORY AIR TECH2, FACTORY AIR TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2'}},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade Support',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 600,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9502', 'zab9502', 'zrb9502', 'zsb9502', 'znb9502' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTime', { 420 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'FACTORY AIR TECH2, FACTORY AIR TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2'}},
                { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 8, 'FACTORY TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'FACTORY TECH3' } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION TECH3'}},
                { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'FACTORY TECH3' } },
                { MIBC, 'GreaterThanGameTime', { 900 } },
            },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support UEF',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade1',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support AEON',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade2',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support Cybran',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade3',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
        },
        BuilderType = 'Any',
    },
    Builder { BuilderName = 'RNGAI T2 Land Factory Upgrade Support Sera',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade4',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgrade', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade',
        PlatoonTemplate = 'T2AirFactoryUpgrade',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 4, 'FACTORY AIR TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3'}},
                { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'FACTORY TECH3' } },
                { MIBC, 'GreaterThanGameTime', { 900 } },
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
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTime', { 420 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 6, 'FACTORY TECH2, FACTORY TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'FACTORY TECH2'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2'}},
                { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
}