--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory LandScout T1 Burst',
        PlatoonTemplate = 'T1LandScout',
        Priority = 895,
        BuilderConditions = {
            { UCBC, 'PoolLessAtLocation', {'LocationType', 3, categories.LAND * categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 1.0 }},
            { UCBC, 'CheckPerimeterPointsExpired', {'Restricted'}},
            { UCBC, 'GreaterThanArmyThreat', { 'LandNow', 20}},
        },
        BuilderType = 'Air',
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