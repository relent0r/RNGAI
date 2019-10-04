--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Tank',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 80, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.LAND * categories.MOBILE - categories.ENGINEER }},
        },
        BuilderType = 'Land',
    },
}