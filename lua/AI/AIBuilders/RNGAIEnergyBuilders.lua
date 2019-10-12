--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnergyToMassRatioIncome', { 15.0, '<=', true} }, -- True if we have 10 times more Energy then Mass income ( 100 >= 10 = true )
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH2' }}, -- Don't build after 2 T2 Pgens Exist
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
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
        BuilderName = 'RNGAI T2 Power Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 1000,
        BuilderConditions = {
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.1 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
        },
        BuilderType = 'Any',
        BuilderData = {
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
        BuilderConditions = { },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                    'T1LandFactory',
                },
            }
        }

    },
}
