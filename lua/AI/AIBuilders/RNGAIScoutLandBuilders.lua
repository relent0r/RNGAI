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
    -- Opening Scout Build --
    Builder {
        BuilderName = 'RNGAI Factory Scout Initial',
        PlatoonTemplate = 'T1LandScout',
        Priority = 950, -- Try to get out before second engie group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.LAND * categories.SCOUT }},
            { UCBC, 'LessThanGameTimeSeconds', { 180 } }, -- don't build after 3 minutes
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 750, -- Try to get out before second engie group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.LAND * categories.SCOUT }},
            { UCBC, 'LessThanGameTimeSeconds', { 1800 } }, -- don't build after 30 minutes *test this properly, expecting good radar by then.
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
        PlatoonTemplate = 'T1LandScoutForm',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.LAND * categories.SCOUT } },
        },
        LocationType = 'LocationType',
        BuilderType = 'Any',
    },
}