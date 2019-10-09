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
        BuilderName = 'CDR Initial Land Standard Small',
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
                    'T1LandFactory',
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
        BuilderName = 'CDR Initial Land Standard Large',
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
    Builder {
        BuilderName = 'CDR Assist T1 Power',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ENERGYPRODUCTION TECH1'}},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.5 }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Engineer',
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ENERGYPRODUCTION TECH1'},
                Time = 20,
            },
        }
    },
}
