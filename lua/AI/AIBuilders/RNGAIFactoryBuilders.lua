--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Factory Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Land',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Land T1',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        InstanceCount = 1,
        BuilderConditions = {
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconTrend', { 0.7, 2.0 }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            -- Respect UnitCap
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Factory Builder Air',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Factory Builder Air T1',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        InstanceCount = 1,
        BuilderConditions = {
            -- When do we want to build this ?
            { EBC, 'GreaterThanEconTrend', { 0.7, 8.0 }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            -- Don't build it if...
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 3, categories.STRUCTURE * categories.FACTORY * categories.TECH1 }},
            -- disabled after using FactoryCapCheck { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.STRUCTURE * categories.FACTORY * categories.TECH1 * categories.AIR }},
            -- Respect UnitCap
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
}