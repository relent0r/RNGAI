--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local SAI = '/lua/ScenarioPlatoonAI.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Small Close',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close',
        PlatoonAddBehaviors = {'CommanderBehavior',},
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1000,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }

    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Small Distant',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Distant',
        PlatoonAddBehaviors = {'CommanderBehavior',},
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1000,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }

    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large',
        PlatoonAddBehaviors = {'CommanderBehavior',},
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1000,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Construction = {
                BuildStructures = {
                    'T1LandFactory',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1AirFactory',
                    'T1EnergyProduction',
                }
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR T1 Land Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuilderConditions = {
            { EBC, 'GreaterThanEconIncome',  { 0.7, 8.0}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.15}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 5, 'FACTORY LAND TECH1' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR T1 Air Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuilderConditions = {
            { EBC, 'GreaterThanEconIncome',  { 0.7, 8.0}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.15}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 3, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, categories.TECH1 * categories.ENERGYPRODUCTION } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 990,
        BuilderConditions = {            
            { UCBC, 'LessThanEnergyTrend', { 0.0 } }, -- If our energy is trending into negatives
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.2 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.6 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Storage',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 990,
        BuilderConditions = {            
            { EBC, 'LessThanEconStorageRatio', { 0.0, 0.50}}, -- Ratio from 0 to 1. (1=100%) -- If our energy is trending into negatives
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.2 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.6 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Build Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Engineer',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ALLUNITS'}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.4, 0.4}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Engineer',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.9}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Factory',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ALLUNITS'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Structure',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ENERGYPRODUCTION, FACTORY, STRUCTURE DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.6} },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Structure',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },
}