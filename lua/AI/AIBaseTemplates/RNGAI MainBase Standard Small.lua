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
        'RNGAI ACU Build Assist',

        -- Intel Builders --
        'RNGAI RadarBuilders',
        'RNGAI RadarUpgrade T1',

        -- Economy Builders --
        'RNGAI Energy Builder',
        'RNGAI Mass Builder',
        'RNGAI MassStorageBuilder',
        'RNGAI Hydro Builder',
        'RNGAI ExtractorUpgrades',

        -- Engineer Builders --
        'RNGAI Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Assist Builders',
        'RNGAI T2 Reclaim Assist Builders',

        -- Land Unit Builders T1 --
        'RNGAI Engineer Builder',
        'RNGAI ScoutLandBuilder',
        'RNGAI LabLandBuilder',
        'RNGAI TankLandBuilder',
        'RNGAI Land AA 2',
        'RNGAI T1 Reaction Tanks',
        'RNGAI T2 TankLandBuilder',

        -- Land Unit Formers T1 --
        'RNGAI ScoutLandFormer',
        'RNGAI Land FormBuilders',
        'RNGAI Mass Hunter Labs FormBuilders',

        -- Land Factory Builders --
        'RNGAI Factory Builder Land',

        -- Land Factory Formers --
        'RNGAI T1 Upgrade Builders',

        -- Air Factory Builders --
        'RNGAI Factory Builder Air',
        'RNGAI Air Staging Platform',

        -- Air Unit Builders T1 --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder',

        -- Air Unit Formers T1 --
        'RNGAI ScoutAirFormer',
        'RNGAI Air Platoon Builder',

        -- Defence Builders --
        'RNGAI Base Defenses',
        'RNGAI T1 Perimeter Defenses',

        -- Expansions --
        'RNGAI Engineer Expansion Builders Small',

    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 10,
            Tech2 = 7,
            Tech3 = 4,
            SCU = 3,
        },
        FactoryCount = {
            Land = 9,
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