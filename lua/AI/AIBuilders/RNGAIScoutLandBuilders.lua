--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory LandScout T1 Burst',
        PlatoonTemplate = 'T1LandScout',
        Priority = 895,
        BuilderConditions = {
            { UCBC, 'PoolLessAtLocation', {'LocationType', 1, categories.LAND * categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.90 }},
            { UCBC, 'GreaterThanArmyThreat', { 'LandNow', 20}},
            { MIBC, 'ScoutsRequiredForBase', {'LocationType', 1.5, categories.LAND * categories.SCOUT }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
        PlatoonTemplate = 'RNGAILandScoutStateMachine',
        Priority = 1001,
        InstanceCount = 60,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 0, categories.LAND * categories.SCOUT } },
        },
        BuilderData = {
            LocationType = 'LocationType',
            StateMachine = 'LandScout'
        },
    },
}