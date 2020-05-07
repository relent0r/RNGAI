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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.35}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, 'FACTORY LAND TECH2' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 8, 'FACTORY LAND TECH1' }},
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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 7, 'FACTORY LAND TECH2' }},
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
    BuilderGroupName = 'RNGAI Factory Builder Unmarked Spam',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Unmarked Spam',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.30}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.5, 0.7 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 8, 'FACTORY LAND TECH1' }},
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
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land Large',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.40}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, 'FACTORY LAND TECH2' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY LAND TECH1' }},
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
        BuilderName = 'RNG Factory Builder Land T1 Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, 'FACTORY LAND TECH2' }},
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
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 Path Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 8, 'FACTORY LAND TECH2' }},
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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 105, 1200 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.FACTORY * categories.LAND}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, 'FACTORY AIR TECH1' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
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
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.COMMAND}},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
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
        BuilderName = 'RNG Factory Builder Air T1 Main Late',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.COMMAND}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
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
    BuilderGroupName = 'RNGAI Factory Builder Air Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1 High Pri Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'MAIN', 1, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, 'FACTORY AIR TECH1' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
         },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
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
        BuilderName = 'RNG Factory Builder Air T1 Main Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1, ENGINEER TECH2, ENGINEER TECH3' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.AIR * categories.FACTORY * categories.TECH1 }},
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
    BuilderGroupName = 'RNGAI Factory Builder Sea',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY NAVAL TECH1' }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.STRUCTURE * categories.FACTORY * categories.NAVAL - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY NAVAL TECH1' }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Sea Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.70}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY NAVAL TECH1' }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY NAVAL TECH1' }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Sea Large Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 High Pri Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL - categories.SUPPORTFACTORY } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY NAVAL TECH1' }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Factory Builder Sea T1 Marker Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Sea' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY NAVAL TECH1' }},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                NearMarkerType = 'Naval Area',
                LocationRadius = 90,
                Location = 'LocationType',
                BuildStructures = {
                    'T1SeaFactory',
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
        PlatoonTemplate = 'EngineerBuilderRNG', -- Air Staging has been moved to T1 so don't need T2 engineers now.
        Priority = 900,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            -- Do we need additional conditions to build it ?
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 5, categories.STRUCTURE * categories.ENERGYPRODUCTION } },
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.70}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.4, 40.0 }}, -- relative income
            -- Don't build it if...
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.AIRSTAGINGPLATFORM }},
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
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
    BuilderGroupName = 'RNGAI Land Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ Excess',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.80}},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1200, 4000 } },
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
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) * categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 1080 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ Excess',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1200, 8000 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
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
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
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
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Air Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Factory Upgrade HQ',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'FACTORY AIR TECH2, FACTORY AIR TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.FACTORY * categories.AIR}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
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
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'FACTORY AIR TECH2, FACTORY AIR TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2'}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade HQ',
        PlatoonTemplate = 'T2AirFactoryUpgrade',
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, 'ENERGYPRODUCTION TECH3'}},
                { MIBC, 'GreaterThanGameTimeRNG', { 900 } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support UEF',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade1',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Aeon',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade2',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Cybran',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade3',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Factory Upgrade Support Seraphim',
        PlatoonTemplate = 'T2AirSupFactoryUpgrade4',
        Priority = 650,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9602', 'zab9602', 'zrb9602', 'zsb9602', 'znb9602' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.AIR * categories.SUPPORTFACTORY * categories.TECH2 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.3}},
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.TECH2 * categories.AIR }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Upgrade Builders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Sea Factory Upgrade HQ',
        PlatoonTemplate = 'T1SeaFactoryUpgrade',
        Priority = 700,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'FACTORY NAVAL TECH2, FACTORY NAVAL TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.FACTORY * categories.NAVAL}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Sea Factory Upgrade Support',
        PlatoonTemplate = 'T1SeaFactoryUpgrade',
        Priority = 600,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9503', 'zab9503', 'zrb9503', 'zsb9503', 'znb9503' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'FACTORY NAVAL TECH2, FACTORY NAVAL TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH1 }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2'}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade HQ',
        PlatoonTemplate = 'T2SeaFactoryUpgrade',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 1500 } },
            { UCBC, 'CheckBuildPlattonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 - categories.SUPPORTFACTORY } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.5}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support UEF',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade1',
        Priority = 600,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support Aeon',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade2',
        Priority = 600,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support Cybran',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade3',
        Priority = 600,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sea Factory Upgrade Support Sera',
        PlatoonTemplate = 'T2SeaSupFactoryUpgrade4',
        Priority = 600,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9603', 'zab9603', 'zrb9603', 'zsb9603', 'znb9603' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.SUPPORTFACTORY * categories.NAVAL * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.8}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Upgrade Builders Expansions',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ Expansions',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade HQ Excess Expansions',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.80}},
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1200, 4000 } },
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Land Factory Upgrade Support Expansions',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 650,
        InstanceCount = 1,
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9501', 'zab9501', 'zrb9501', 'zsb9501', 'znb9501' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 450 } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.STRUCTURE * categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) * categories.SUPPORTFACTORY } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1 }},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
    
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ Expansions',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 1080 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Factory Upgrade HQ Excess Expansions',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
                { EBC, 'GreaterThanEconStorageCurrentRNG', { 1200, 8000 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 - categories.SUPPORTFACTORY } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.30, 0.80}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
                { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 }},
            },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support UEF Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade1',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.UEF * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support AEON Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade2',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AEON * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { 
        BuilderName = 'RNGAI T2 Land Factory Upgrade Support Cybran Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade3',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.CYBRAN * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
    Builder { BuilderName = 'RNGAI T2 Land Factory Upgrade Support Sera Expansions',
        PlatoonTemplate = 'T2LandSupFactoryUpgrade4',
        Priority = 700,
        DelayEqualBuildPlattons = {'FactoryUpgrade', 3},
        BuilderData = {
            OverideUpgradeBlueprint = { 'zeb9601', 'zab9601', 'zrb9601', 'zsb9601', 'znb9601' }, -- overides Upgrade blueprint for all 5 factions. Used for support factories
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 - categories.SUPPORTFACTORY} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SERAPHIM * categories.SUPPORTFACTORY * categories.LAND * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50}},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'FactoryUpgrade' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgraded', { 2, categories.STRUCTURE * categories.FACTORY * categories.TECH2 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land Large Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1 MainBase Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.60}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY LAND TECH2' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, 'FACTORY LAND TECH1' }},
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
        BuilderName = 'RNG Factory Builder Land T1 Large',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, 'FACTORY LAND TECH2' }},
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
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { UCBC, 'HaveLessThanUnitsWithCategory', { 6, 'FACTORY TECH2, FACTORY TECH3'}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'FACTORY TECH2'}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, 'MASSEXTRACTION TECH2'}},
                { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, 'FACTORY TECH2, FACTORY TECH3' } },
                { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80}},
                { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },
            },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Gate Builders',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Gate Builder',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Gate' } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.90 } },             -- Ratio from 0 to 1. (1=100%)
            -- Don't build it if...
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
            -- Respect UnitCap
            { UCBC, 'HaveUnitRatioVersusCap', { 0.02 , '<', categories.STRUCTURE * categories.GATE } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                Location = 'LocationType',
                AdjacencyCategory = 'ENERGYPRODUCTION',
                BuildStructures = {
                    'T3QuantumGate',
                },
            }
        }
    },
}