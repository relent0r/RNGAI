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
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.SCOUT * categories.AIR}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory AirScout T1 Demand',
        PlatoonTemplate = 'T1AirScout',
        Priority = 895,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T1', 'scout'} },
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'ANTIAIR' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading'}},
            { UCBC, 'GreaterThanArmyThreat', { 'AntiAirNow', 20}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
    },
    
    Builder {
        BuilderName = 'RNGAI Factory AirScout T3',
        PlatoonTemplate = 'T3AirScout',
        Priority = 900,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.SCOUT * categories.AIR}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory AirScout T3 Demand',
        PlatoonTemplate = 'T3AirScout',
        Priority = 897,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T3', 'scout'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading'}},
            { UCBC, 'GreaterThanArmyThreat', { 'AntiAirNow', 120}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
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
            StateMachine = 'AirScout'
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
            StateMachine = 'AirScout',
            PerimeterPoints = true,
            ExpansionPatrol = true,
            LocationType = 'LocationType',
        },
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
            StateMachine = 'AirScout',
            ACUSupport = true,
            PatrolTime = 10,
            LocationType = 'LocationType',
        },
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
            StateMachine = 'AirScout',
            Patrol = true,
            PatrolTime = 120,
            LocationType = 'LocationType',
        },
        BuilderType = 'Any',
    },
}