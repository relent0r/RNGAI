


local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'


BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Base Defenses',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 875,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, 'DEFENSE'}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.2, 1.5 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                    'T1GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

-- Defenses surrounding the base in patrol points

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Perimeter Defenses',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence - Perimeter',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 910,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 5, categories.DEFENSE * categories.TECH1}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.2, 1.5 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                NearBasePatrolPoints = true,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}