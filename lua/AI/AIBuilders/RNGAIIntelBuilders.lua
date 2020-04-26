--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIIntelBuilders.lua
    Author  :   relentless
    Summary :
        Intel Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarBuilders',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Radar T1',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, (categories.RADAR + categories.OMNI) * categories.STRUCTURE}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 5.0 }},
            { MIBC, 'GreaterThanGameTime', { 240 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION,
                AdjacencyDistance = 50,
                BuildStructures = {
                    'T1Radar',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarUpgrade',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Radar Upgrade',
        PlatoonTemplate = 'T1RadarUpgrade',
        Priority = 600,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.2, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
            { MIBC, 'GreaterThanGameTime', { 600 } },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Radar Upgrade',
        PlatoonTemplate = 'T2RadarUpgrade',
        Priority = 600,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.2, 0.90}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.0 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarUpgrade T1 Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Radar Upgrade Expansion',
        PlatoonTemplate = 'T1RadarUpgrade',
        Priority = 600,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 600 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.TECH2 * categories.RADAR }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.3, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
        },
        BuilderType = 'Any',
    },
}