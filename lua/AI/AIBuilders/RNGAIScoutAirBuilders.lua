--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutAirBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory AirScout T1',
        PlatoonTemplate = 'T1AirScout',
        Priority = 900,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.01, 0.3}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.SCOUT * categories.AIR}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory AirScout T1 Excess',
        PlatoonTemplate = 'T1AirScout',
        Priority = 300,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.SCOUT * categories.AIR}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.8}},
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutAirFormer',
    BuildersType = 'PlatoonFormBuilder',
    -- Opening Scout Form --
    Builder {
        BuilderName = 'RNGAI Former Scout Air',
        PlatoonTemplate = 'RNGAI AirScoutForm',
        PlatoonAddBehaviors = {'ACUDetection',},
        InstanceCount = 1,
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.SCOUT } },
        },
        BuilderData = {
            ScanWait = 20,
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Former Scout Air Excess',
        PlatoonTemplate = 'RNGAI AirScoutForm',
        PlatoonAddBehaviors = {'ACUDetection',},
        InstanceCount = 12,
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.SCOUT } },
        },
        BuilderData = {
            ScanWait = 20,
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Former Scout ACU Support',
        PlatoonTemplate = 'RNGAI AirScoutForm',
        InstanceCount = 1,
        Priority = 950,
        BuilderConditions = {
            { MIBC, 'ACURequiresSupport', {} },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.SCOUT } },
            
        },
        BuilderData = {
            ACUSupport = true,
            PatrolTime = 10,
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Former Scout Patrol',
        PlatoonTemplate = 'RNGAI AirScoutForm',
        InstanceCount = 2,
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.SCOUT } },
        },
        BuilderData = {
            Patrol = true,
            PatrolTime = 120,
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
}