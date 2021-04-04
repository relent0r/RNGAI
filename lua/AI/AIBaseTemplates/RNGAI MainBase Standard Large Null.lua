--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Large Null',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Large',

        -- ACU MainBase Builder --
        'RNGAI ACU Structure Builders Large',

        -- Engineer Builders --
        'RNGAI Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        'RNGAI Assist Builders',
        'RNGAI Energy Production Reclaim',

        -- Intel Builders --
        'RNGAI RadarBuilders Expansion',
        'RNGAI RadarUpgrade',
        'RNGAI RadarUpgrade T1 Expansion',
        
        -- Economy Builder --
        'RNGAI Energy Builder',
        'RNGAI Energy Storage Builder',
        'RNGAI Mass Builder',
        'RNGAI Mass Storage Builder',
        'RNGAI Hydro Builder',
        'RNGAI Mass Fab',

        -- Scout Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI ScoutLandBuilder',

        -- Scout Formers --
        'RNGAI ScoutAirFormer',
        'RNGAI ScoutLandFormer',
        
        -- Defence Builders --
        'RNGAI Base Defenses',
        'RNGAI Perimeter Defenses Small',
        'RNGAI T2 Defense FormBuilders',
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',

        -- Land Unit Formers T1 --
        'RNGAI ScoutLandFormer',
        'RNGAI Land Mass Raid',
        'RNGAI Land FormBuilders',
        'RNGAI Mass Hunter Labs FormBuilders',
        'RNGAI Land Response Formers',

        -- Air Unit Builders --
        'RNGAI TransportFactoryBuilders Large',

        -- Air Unit Formers --
        'RNGAI Air Response Formers',
        'RNGAI Air Platoon Builder',

        -- Land Factory Builders --
        'RNGAI Factory Builder Land Large',

        -- Land Upgrade Builders --
        'RNGAI Land Upgrade Builders',

        -- Air Upgrade Builders --
        'RNGAI Air Upgrade Builders',

        -- RNGAI Air Support Builders --
        'RNGAI Air Staging Platform',

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGAI SACU Builder',

        -- Strategic Builders
        'RNGAI SML Builders',
        'RNGAI Strategic Artillery Builders',
        'RNGAI Strategic Formers',

        -- Experimentals --
        --'RNGAI Experimental Builders',
        'RNGAI Experimental Formers',

        -- Sea Builders --
        --'RNGAI Sea Builders T1',

        -- Sea Formers --
        --'RNGAI Sea Formers',
    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 15,
            Tech2 = 12,
            Tech3 = 10,
            SCU = 6,
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
        if personality == 'RNGStandardnull' and mapSizeX > 1000 and mapSizeZ > 1000 or personality == 'RNGStandardcheatnull' and mapSizeX > 1000 and mapSizeZ > 1000 then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is large', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandardnull'
        end
        return -1
    end,
}