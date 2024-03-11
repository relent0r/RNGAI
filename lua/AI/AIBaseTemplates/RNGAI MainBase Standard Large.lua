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

        -- ACU MainBase Builder --
        'RNGAI ACU Structure Builders Large',
        'RNGAI ACU Build Assist',

        -- Expansion Builders --
        'RNGAI Engineer Expansion Builders Large',

        -- Engineer Builders --
        'RNGAI Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        'RNGAI Assist Builders',
        'RNGAI Energy Production Reclaim',
        'RNGAI Land Factory Reclaim',
        'RNGAI Air Factory Reclaim',
        'RNGAI Engineer Transfer To Active Expansion',
        'RNGAI Assist Manager BuilderGroup',

        -- Intel Builders --
        'RNGAI RadarBuilders',
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
        --'RNGAI Perimeter Defenses Large',
        'RNGAI T2 Defense FormBuilders',
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',

        -- Land Unit Builders --
        'RNGAI TankLandBuilder Large',
        'RNGAI Land AA 2',
        'RNGAI T3 AttackLandBuilder Large',
        'RNGAI Island Large FormBuilders',


        -- Land Unit Formers T1 --
        'RNGAI Land Mass Raid',
        'RNGAI Land FormBuilders Large',
        'RNGAI Mass Hunter Labs FormBuilders',
        'RNGAI Land Response Formers',

        -- Air Unit Builders --
        'RNGAI TransportFactoryBuilders Large',
        'RNGAI Air Builder T1',
        'RNGAI Air Builder T2',
        'RNGAI Air Builder T3',
        'RNGAI Air Builder T1 Ratio',
        'RNGAI Air Builder T2 Ratio',
        'RNGAI Air Builder T3 Ratio',

        -- Air Unit Formers --
        'RNGAI Air Response Formers',
        'RNGAI Air Platoon Builder',

        -- Land Factory Builders --
        'RNGAI Factory Builder Land Large',
        'RNGAI Reaction Tanks',
        'RNGAI LandBuilder T1',
        'RNGAI LandBuilder T2',
        'RNGAI LandBuilder T3',
        'RNGAI LandBuilder T1 Islands',

        -- Air Factory Builders --
        'RNGAI Factory Builder Air Large',

        -- RNGAI Air Support Builders --
        'RNGAI Air Staging Platform',

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGAI SACU Builder',

        -- Strategic Builders
        'RNGAI SML Builders',
        'RNGAI Strategic Artillery Builders Large',
        'RNGAI Strategic Formers',

        -- Experimentals --
        'RNGAI Experimental Builders',
        'RNGAI Experimental Formers',

    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 25,
            Tech2 = 18,
            Tech3 = 12,
            SCU = 10,
        },
        FactoryCount = {
            Land = 12,
            Air = 6,
            Sea = 6,
            Gate = 1,
        },
        MassToFactoryValues = {
            T1LandValue = 4.5,
            T2LandValue = 14,
            T3LandValue = 25,
            T1AirValue = 3.5,
            T2AirValue = 10,
            T3AirValue = 24,
            T1NavalValue = 4,
            T2NavalValue = 16,
            T3NavalValue = 30,
        },

    },
    ExpansionFunction = function(aiBrain, location, markerType)
        return -1
    end,
    FirstBaseFunction = function(aiBrain)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'RNGStandard' and mapSizeX > 1000 and mapSizeZ > 1000 or personality == 'RNGStandardcheat' and mapSizeX > 1000 and mapSizeZ > 1000 then
            --RNGLOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --RNGLOG('* AI-RNG: Map size is large', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandard'
        end
        return -1
    end,
}