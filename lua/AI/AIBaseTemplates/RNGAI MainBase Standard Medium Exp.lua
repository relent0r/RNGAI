--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard Exp.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Medium Exp Close',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Small',

        -- ACU Other Builders --
        'RNGAI ACU Build Assist',
        'RNGAI ACU Structure Builders',

        -- Intel Builders --
        'RNGAI RadarBuilders',
        'RNGAI RadarUpgrade',

        -- Economy Builders --
        'RNGAI Energy Builder',
        'RNGAI Energy Storage Builder',
        'RNGAI Mass Builder',
        'RNGAI Mass Storage Builder',
        'RNGAI Hydro Builder',
        'RNGAI Mass Fab',

        -- Engineer Builders --
        'RNGEXP Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        'RNGAI Assist Builders',
        'RNGEXP Hard Assist Builders',
        'RNGAI Energy Production Reclaim',
        'RNGAI Engineer Transfer To Active Expansion',
        'RNGAI Assist Manager BuilderGroup',

        -- Land Factory Builders --
        'RNGEXP Factory Builder Land',

        -- Land Unit Builders
        'RNGAI LandBuilder T1',
        'RNGAI LandBuilder T2',
        'RNGAI LandBuilder T3',
        'RNGAI LandBuilder T1 Islands',
        -- Land Formers
        'RNGAI ScoutLandFormer',
        'RNGAI Land Mass Raid',
        'RNGAI Land FormBuilders',
        'RNGAI Mass Hunter Labs FormBuilders',
        'RNGAI Land Response Formers',

        -- Air Factory Builders --
        'RNGEXP Factory Builder Air',
        'RNGAI Air Staging Platform',
        
        -- Air Unit Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder T1',
        --'RNGAI Air Builder T2',
        'RNGAI Air Builder T3',
        'RNGAI TransportFactoryBuilders Small',


        

        -- Air Unit Formers --
        'RNGAI ScoutAirFormer',
        'RNGEXP Air Platoon Builder',
        'RNGAI Air Response Formers',

        -- Sea Unit Builders
        --'RNGAI Sea Builders T1',
        
        -- Sea Unit Formers
        --'RNGAI Sea Formers',
        --'RNGAI Mass Hunter Sea Formers',
        
        -- Defence Builders --
        'RNGAI Base Defenses',
        --'RNGAI Perimeter Defenses Small',
        'RNGAI T2 Defense FormBuilders',
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',

        -- Expansions --
        'RNGAI Engineer Expansion Builders Small',

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGEXP SACU Builder',

        --Strategic Builders
        'RNGAI SML Builders',
        'RNGAI Strategic Artillery Builders Small',
        'RNGAI Strategic Formers',

        --Experimentals --
        'RNGAI Experimental Builders',
        'RNGAI Experimental Formers',
    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 20,
            Tech2 = 15,
            Tech3 = 22,
            SCU = 100,
        },
        FactoryCount = {
            Land = 2,
            Air = 6,
            Sea = 1,
            Gate = 1,
        },
        MassToFactoryValues = {
            T1LandValue = 4,
            T2LandValue = 1,
            T3LandValue = 28,
            T1AirValue = 4,
            T2AirValue = 1,
            T3AirValue = 28,
            T1NavalValue = 4,
            T2NavalValue = 1,
            T3NavalValue = 28,
        },

    },
    ExpansionFunction = function(aiBrain, location, markerType)
        return -1
    end,
    FirstBaseFunction = function(aiBrain)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'RNGStandardExperimental' and mapSizeX > 1000 and mapSizeZ > 1000 or personality == 'RNGStandardExperimentalcheat' and mapSizeX > 1000 and mapSizeZ > 1000 then
            --RNGLOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --RNGLOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandardExperimental'
        end
        return -1
    end,
}