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
        'RNGAI ACU Structure Builders',

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
        'RNGAI T1 Reclaim Builders',
        'RNGAI T1 Assist Builders',
        'RNGAI T2 Assist Builders',

        -- Land Unit Builders T1 --
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
        'RNGAI Land FormBuilders AntiMass',

        -- Land Factory Builders --
        'RNGAI Factory Builder Land',

        -- Land Factory Formers --
        'RNGAI T1 Upgrade Builders',

        -- Air Factory Builders --
        'RNGAI Factory Builder Air',
        'RNGAI Air Staging Platform',

        -- Air Unit Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder T1',
        'RNGAI Air Builder T2',

        -- Air Unit Formers --
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
            Tech1 = 16,
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
            T1Value = 5,
            T2Value = 14,
            T3Value = 21,
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
            return 1000, 'RNGStandard'
        end
        return -1
    end,
}