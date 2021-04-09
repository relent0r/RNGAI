--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard Air.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small Air Close',
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
        'RNGAI Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        'RNGAI Assist Builders',
        'RNGAI Energy Production Reclaim',

        -- Air Factory Builders --
        'RNGAI Factory Builder Air',
        'RNGAI Air Staging Platform',
        
        -- Air Factory Formers --
        'RNGAI Air Upgrade Builders',

        -- Air Unit Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder T1',
        'RNGAI Air Builder T2',
        'RNGAI Air Builder T3',
        'RNGAI TransportFactoryBuilders Small',

        -- Air Unit Formers --
        'RNGAI ScoutAirFormer',
        'RNGAI Air Platoon Builder',
        'RNGAI Air Response Formers',

        -- Sea Unit Builders
        --'RNGAI Sea Builders T1',
        
        -- Sea Unit Formers
        --'RNGAI Sea Formers',
        --'RNGAI Mass Hunter Sea Formers',
        
        -- Defence Builders --
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGAI SACU Builder',

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
            Tech2 = 9,
            Tech3 = 6,
            SCU = 3,
        },
        FactoryCount = {
            Land = 15,
            Air = 5,
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
        if personality == 'RNGStandardAir' and mapSizeX < 1000 and mapSizeZ < 1000 or personality == 'RNGStandardAircheat' and mapSizeX < 1000 and mapSizeZ < 1000 then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandardAir'
        end
        return -1
    end,
}