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
        BuilderName = 'RNGAI Factory Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 750, -- After second engie group
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.5}},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.LAND * categories.SCOUT }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.LAND * categories.SCOUT } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.3, 0.5 }},
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