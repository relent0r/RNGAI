--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local IBC = '/lua/editor/InstantBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 60',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 950,
        InstanceCount = 2,
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
        Priority = 900,
        InstanceCount = 2,
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

    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 240',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnMassLessThanLocationDistance', { 'LocationType', 240, -500, 0, 0, 'AntiSurface', 1, 'RNGAI T1Engineer Mass 240'}},
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
        BuilderName = 'RNGAI T1Engineer Mass 480',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        InstanceCount = 2,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnMassLessThanLocationDistance', { 'LocationType', 480, -500, 0, 0, 'AntiSurface', 1, 'RNGAI T1Engineer Mass 480'}},
            { UCBC, 'CanBuildOnMassGreaterThanLocationDistance', { 'LocationType', 120, -500, 0, 0, 'AntiSurface', 1, 'RNGAI T1Engineer Mass 480'}},
            { MIBC, 'GreaterThanGameTime', { 180 } },
            
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = true,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
}
