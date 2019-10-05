--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI LabLandBuilder',
    BuildersType = 'FactoryBuilder',
    -- Opening Lab Build --
    Builder {
        BuilderName = 'RNGAI Factory Lab',
        PlatoonTemplate = 'T1LandDFBot',
        Priority = 90, -- Try to get out before second engie group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 1, 2, 3, 5 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'LessThanGameTimeSeconds', { 180 } }, -- don't build after 3 minutes
        },
        BuilderType = 'Land',
    },
}