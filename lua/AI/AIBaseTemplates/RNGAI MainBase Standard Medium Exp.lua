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
        --'RNGAI Test PD',
        --'RNGAI ACU Enhancements Gun',
        --'RNGAI ACU Enhancements Tier',

        -- Intel Builders --
        'RNGAI RadarBuilders',
        'RNGAI RadarUpgrade',

        -- Economy Builders --
        'RNGAI Energy Builder',
        'RNGAI Energy Storage Builder',
        'RNGAI Mass Builder',
        'RNGAI Mass Storage Builder',
        'RNGAI Hydro Builder',
        --'RNGAI ExtractorUpgrades',
        'RNGAI Mass Fab',

        -- Engineer Builders --
        'RNGEXP Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        'RNGAI Assist Builders',
        'RNGEXP Hard Assist Builders',
        'RNGAI Energy Production Reclaim',
        'RNGAI Engineer Transfer To Active Expansion',

        -- Land Factory Builders --
        'RNGEXP Factory Builder Land',

        -- Air Factory Builders --
        'RNGEXP Factory Builder Air',
        'RNGAI Air Staging Platform',
        
        -- Air Factory Formers --
        'RNGEXP Air Upgrade Builders',

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
        'RNGAI Perimeter Defenses Small',
        'RNGAI T2 Defense FormBuilders',
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',
        'RNGAI Perimeter Defenses Expansions',

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
        'RNGEXP Experimental Builders',
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
            T1Value = 4,
            T2Value = 11,
            T3Value = 19,
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