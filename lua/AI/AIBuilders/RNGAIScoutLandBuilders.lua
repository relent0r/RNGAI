--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI ScoutLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 95, -- Try to get out before second engie group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.LAND * categories.SCOUT }},
        },
        BuilderType = 'Land',
    },
}