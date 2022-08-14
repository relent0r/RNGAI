--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutAirBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory AirScout T1',
        PlatoonTemplate = 'T1AirScout',
        Priority = 900,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.0, 0.60}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.SCOUT * categories.AIR}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory AirScout T1 Excess',
        PlatoonTemplate = 'T1AirScout',
        Priority = 760,
        BuilderConditions = {
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { UCBC, 'PoolLessAtLocation', { 'LocationType', 2, categories.AIR * categories.SCOUT } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'GreaterThanArmyThreat', { 'AntiAirNow', 10}},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory AirScout T1 Burst',
        PlatoonTemplate = 'RNGAIT1AirScoutBurst',
        Priority = 895,
        BuilderConditions = {
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 1.0 }},
            { UCBC, 'CheckPerimeterPointsExpired', {'Restricted'}},
            { UCBC, 'GreaterThanArmyThreat', { 'AntiAirNow', 20}},
        },
        BuilderType = 'Air',
    },
    
    Builder {
        BuilderName = 'RNGAI Factory AirScout T3',
        PlatoonTemplate = 'T3AirScout',
        Priority = 900,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.SCOUT * categories.AIR}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.AIR * categories.TECH3 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory AirScout T3 Excess',
        PlatoonTemplate = 'T3AirScout',
        Priority = 761,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0 }},
            { UCBC, 'PoolLessAtLocation', { 'LocationType', 2, categories.AIR * categories.SCOUT } },
            { UCBC, 'GreaterThanArmyThreat', { 'AntiAirNow', 30}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.AIR * categories.TECH3 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory AirScout T3 Burst',
        PlatoonTemplate = 'T3AirScout',
        Priority = 897,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 1.0 }},
            { UCBC, 'CheckPerimeterPointsExpired', {'Restricted'}},
            { UCBC, 'GreaterThanArmyThreat', { 'AntiAirNow', 120}},
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
        InstanceCount = 1,
        Priority = 910,
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
        InstanceCount = 30,
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.AIR * categories.SCOUT } },
        },
        BuilderData = {
            PerimeterPoints = true,
            ExpansionPatrol = true,
            ScanWait = 20,
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Former Scout ACU Support',
        PlatoonTemplate = 'RNGAI AirScoutSingle',
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
        PlatoonTemplate = 'RNGAI AirScoutSingle',
        InstanceCount = 1,
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