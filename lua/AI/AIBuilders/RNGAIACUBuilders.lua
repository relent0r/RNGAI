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

-- this builder group is a test for attempting a PD surounded by walls..not working :(
BuilderGroup {
    BuilderGroupName = 'RNGAI Test PD',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Test pd',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1060,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'STRUCTURE DEFENSE TECH1' }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                --BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/RNGAIT1PDTemplate.lua',
                --BaseTemplate = 'T1PDTemplate',
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    'T1GroundDefense', 
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Test wall',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1050,
        BuilderConditions = {
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                --BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/RNGAIT1PDTemplate.lua',
                --BaseTemplate = 'T1PDTemplate',
                LocationType = 'LocationType',
                BuildClose = true,
                Wall = true,
                MarkerRadius = 50,
                MarkerUnitCount = 1,
                MarkerUnitCategory = 'STRUCTURE - WALL',
                --MarkerUnitCategory = 'DEFENSE',
                BuildStructures = {
                    --'T1GroundDefense', 
                    'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                    --'Wall',
                },
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
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0} },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
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
        Priority = 800,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.0} },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY AIR TECH1' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI CDR T1 Power',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 700,
        BuilderConditions = {            
            { UCBC, 'LessThanEnergyTrend', { 0.0 } }, -- If our energy is trending into negatives
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.4 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.4 }},
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 1, 'ENGINEER TECH2, ENGINEER TECH3' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = 'FACTORY',
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
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ALLUNITS'}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Engineer',
                AssistRange = 40,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'MASSEXTRACTION', 'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 800,
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
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ENERGYPRODUCTION, FACTORY, STRUCTURE DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.9} },
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