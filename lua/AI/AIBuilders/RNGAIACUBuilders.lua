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
    BuilderGroupName = 'RNGAI Initial ACU Builder Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small',
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
    BuilderGroupName = 'RNGAI ACU Build Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Engineer',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ENERGYPRODUCTION, FACTORY, STRUCTURE DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.9} },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Engineer',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'MASSEXTRACTION', 'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ENERGYPRODUCTION, FACTORY, STRUCTURE DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.9} },
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
                BeingBuiltCategories = {'MASSEXTRACTION', 'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR T1 Land Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 800,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.1} },
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
        BuilderName = 'RNGAI CDR T1 Power',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 800,
        BuilderConditions = {            
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 0.5 }},
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