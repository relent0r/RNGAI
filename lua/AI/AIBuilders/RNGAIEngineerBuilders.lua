--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Builder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Engineer Initial',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 1000, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 3 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Factory Engineer Small',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 850, -- Top factory priority
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.ENGINEER - categories.COMMAND } }, -- Build engies until we have 6 of them.
        },
        BuilderType = 'All',
    },
    Builder {
        BuilderName = 'RNGAI Engineer Reclaim T1',
        PlatoonTemplate = 'T1EngineerReclaimer',
        PlatoonAIPlan = 'ReclaimAI',
        Priority = 950,
        InstanceCount = 3,
        BuilderConditions = {
                { MIBC, 'ReclaimablesInArea', { 'LocationType', }},
            },
        BuilderData = {
            LocationType = 'LocationType',
        },
        BuilderType = 'Any',
    },
    Builder {
            BuilderName = 'T1 Engineer Assist Engineer',
            PlatoonTemplate = 'EngineerAssist',
            Priority = 500,
            InstanceCount = 20,
            BuilderConditions = {
                { IBC, 'BrainNotLowPowerMode', {} },
                { UCBC, 'LocationEngineersBuildingAssistanceGreater', { 'LocationType', 0, 'ALLUNITS' } },
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
            },
            BuilderType = 'Any',
            BuilderData = {
                Assist = {
                    AssistLocation = 'LocationType',
                    PermanentAssist = true,
                    AssisteeType = 'Engineer',
                    Time = 30,
                },
            }
        },
}