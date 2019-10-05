--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local IBC = '/lua/editor/InstantBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 30',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 100,
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnMassLessThanLocationDistance', { 'LocationType', 30, -500, 0, 0, 'AntiSurface', 1, 'RNGAI T1Engineer Mass 30'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                },
            }
        }

    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 60',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 95,
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnMassLessThanLocationDistance', { 'LocationType', 60, -500, 0, 0, 'AntiSurface', 1, 'RNGAI T1Engineer Mass 60'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 120',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 90,
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnMassLessThanLocationDistance', { 'LocationType', 120, -500, 0, 0, 'AntiSurface', 1, 'RNGAI T1Engineer Mass 120'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
}
