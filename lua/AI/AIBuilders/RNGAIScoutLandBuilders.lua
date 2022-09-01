--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory LandScout T1 Burst',
        PlatoonTemplate = 'RNGAIT1LandScoutBurst',
        Priority = 895,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.LAND * categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 1.0 }},
            { UCBC, 'CheckPerimeterPointsExpired', {'Restricted'}},
            { UCBC, 'GreaterThanArmyThreat', { 'LandNow', 20}},
            { UCBC, 'RatioToZones', { 'Land', categories.LAND * categories.SCOUT, 1.5}},
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutLandFormer',
    BuildersType = 'PlatoonFormBuilder',
    -- Opening Scout Form --
    Builder {
        BuilderName = 'RNGAI Former Scout',
        PlatoonTemplate = 'RNGAI T1LandScoutForm',
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        Priority = 1000,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 0, categories.LAND * categories.SCOUT } },
        },
        BuilderData = {
            LocationType = 'LocationType',
        },
    },
    Builder {
        BuilderName = 'RNGAI Former Scout Excess',
        PlatoonTemplate = 'RNGAI T1LandScoutForm',
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        Priority = 100,
        InstanceCount = 30,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.LAND * categories.SCOUT } },
        },
        BuilderData = {
            LocationType = 'LocationType',
            ExcessScout = true,
        },
    },
}