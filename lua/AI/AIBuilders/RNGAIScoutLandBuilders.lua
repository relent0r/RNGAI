--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutLandBuilder',
    BuildersType = 'FactoryBuilder',
    -- Opening Scout Build --
    Builder {
        BuilderName = 'RNGAI Factory Scout Initial',
        PlatoonTemplate = 'T1LandScout',
        Priority = 950, -- Try to get out before second engie group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.LAND * categories.SCOUT } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 180 } }, -- don't build after 3 minutes
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 700, -- After second engie group
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.5}},
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.LAND * categories.SCOUT }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.SCOUT } },
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
        Priority = 100,
        InstanceCount = 15,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.LAND * categories.SCOUT } },
        },
        BuilderData = {
            LocationType = 'LocationType',
            ExcessScout = true,
        },
    },
}