--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Ratio',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 180 } }, -- so we dont crash the mass in the first few minutes cause thats what we do >_<
            { UCBC, 'EnergyToMassRatioIncome', { 14.0, '<=', true} }, -- True if we have 10 times more Energy then Mass income ( 100 >= 10 = true )
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist

        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = 'FACTORY',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Trend',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'LessThanEnergyTrend', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = 'FACTORY',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer 1st',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 1000,
        BuilderConditions = {
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.1 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = 'FACTORY',
            DesiresAssist = true,
            Construction = {
                NumAssistees = 2,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'ENERGYPRODUCTION TECH2' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 0.1 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = 'FACTORY',
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Expansion',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnergyToMassRatioIncome', { 15.0, '<=', true} }, -- True if we have 10 times more Energy then Mass income ( 100 >= 10 = true )
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }

    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Expansion',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.1 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = 'FACTORY',
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Hydro Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Hydro',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistance', { 'LocationType', 256, -1000, 100, 1, 'AntiSurface', 1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                },
            }
        }

    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Storage Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'T1 Energy Storage Builder OverCharge',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYSTORAGE' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'EnergyStorage',
                },
            }
        }
    },
    Builder {
        BuilderName = 'T1 Energy Storage Builder',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 600 } },
            { UCBC, 'UnitCapCheckLess', { .7 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, 'ENERGYSTORAGE' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'EnergyStorage',
                },
            }
        }
    },
}
