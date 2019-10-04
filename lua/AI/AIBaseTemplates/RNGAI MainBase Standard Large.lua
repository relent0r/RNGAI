--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Large',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Large',

        -- Economy Builder --
        'RNGAI Energy Builder',
        'RNGAI Mass Builder',

        -- Land Unit Builders T1 --
        'RNGAI LandBuilder',
        'RNGAI ScoutLandBuilder',
        'RNGAI LabLandBuilder',
        'RNGAI TankLandBuilder',
    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 9,
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
        if personality == 'RNGStandard' and mapSizeX > 1000 and mapSizeZ > 1000 or personality == 'RNGStandardCheat' and mapSizeX > 1000 and mapSizeZ > 1000 then
            --LOG('### M-FirstBaseFunction '..personality)
            LOG('Map size is large', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandardMainBaseTemplate Large'
        end
        return -1
    end,
}