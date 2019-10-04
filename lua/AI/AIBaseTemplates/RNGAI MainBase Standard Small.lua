--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Small',
        'RNGAI Energy Builder',
        'RNGAI Mass Builder',
        'RNGAI LandBuilder',
    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 6,
            Tech2 = 3,
            Tech3 = 3,
            SCU = 2,
        },
        FactoryCount = {
            Land = 6,
            Air = 3,
            Sea = 0,
            Gate = 1,
        },
        MassToFactoryValues = {
            T1Value = 6,
            T2Value = 15,
            T3Value = 22.5,
        },

    },
    ExpansionFunction = function(aiBrain, location, markerType)
        return -1
    end,
    FirstBaseFunction = function(aiBrain)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'RNGStandard' and mapSizeX < 1000 and mapSizeZ < 1000 or personality == 'RNGStandardCheat' and mapSizeX < 1000 and mapSizeZ < 1000 then
            --LOG('### M-FirstBaseFunction '..personality)
            LOG('Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandardMainBaseTemplate Small'
        end
        return -1
    end,
}