--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard Exp.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small Exp Close',
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

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGEXP SACU Builder',

        --Strategic Builders
        'RNGAI SML Builders',
        'RNGAI Strategic Artillery Builders',
        'RNGAI Strategic Formers',

        --Experimentals --
        'RNGAI Experimental Builders',
        'RNGAI Experimental Formers',
    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 30,
            Tech2 = 18,
            Tech3 = 12,
            SCU = 100,
        },
        FactoryCount = {
            Land = 2,
            Air = 3,
            Sea = 1,
            Gate = 1,
        },
        MassToFactoryValues = {
            T1LandValue = 4.5,
            T2LandValue = 15,
            T3LandValue = 26,
            T1AirValue = 4.5,
            T2AirValue = 15,
            T3AirValue = 26,
            T1NavalValue = 4.5,
            T2NavalValue = 15,
            T3NavalValue = 26,
        },

    },
    ExpansionFunction = function(aiBrain, location, markerType)
        return -1
    end,
    FirstBaseFunction = function(aiBrain)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'RNGStandardExperimental' and mapSizeX < 1000 and mapSizeZ < 1000 or personality == 'RNGStandardExperimentalcheat' and mapSizeX < 1000 and mapSizeZ < 1000 then
            --RNGLOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --RNGLOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandardExperimental'
        end
        return -1
    end,
}