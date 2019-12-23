--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutAirBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory AirScout T1',
        PlatoonTemplate = 'T1AirScout',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.SCOUT * categories.AIR}},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY AIR TECH3' }},
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutAirFormer',
    BuildersType = 'PlatoonFormBuilder',
    -- Opening Scout Form --
    Builder {
        BuilderName = 'RNGAI Former Scout T1',
        PlatoonTemplate = 'RNGAI T1AirScoutForm',
        PlatoonAddBehaviors = {'ACUDetection',},
        InstanceCount = 2,
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AIR * categories.SCOUT } },
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
    Builder {
    BuilderName = 'RNGAI Former Scout T3',
        PlatoonTemplate = 'RNGAI T3AirScoutForm',
        InstanceCount = 3,
        Priority = 910,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AIR * categories.SCOUT } },
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Former Scout Patrol DMZ T1',
        PlatoonTemplate = 'RNGAI T1AirScoutForm',
        InstanceCount = 2,
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AIR * categories.SCOUT } },
        },
        BuilderData = {
            Patrol = true,
            PatrolTime = 120,
            --MilitaryArea = 'BaseDMZArea',
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Former Scout Patrol DMZ T3',
        PlatoonTemplate = 'RNGAI T3AirScoutForm',
        InstanceCount = 1,
        Priority = 900,
        BuilderData = {
            Patrol = true,
            PatrolTime = 120,
            --MilitaryArea = 'BaseDMZArea',
        },
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AIR * categories.SCOUT } },
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
}