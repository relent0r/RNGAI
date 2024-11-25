--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small Close',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Small',

        -- ACU Other Builders --
        'RNGAI ACU Build Assist',
        'RNGAI ACU Structure Builders',

        -- Intel Builders --
        'RNGAI RadarBuilders',
        'RNGAI RadarUpgrade',
        'RNGAI Intel Formers',

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
        'RNGAI Land Factory Reclaim',
        'RNGAI Air Factory Reclaim',
        'RNGAI Engineer Transfer To Active Expansion',
        'RNGAI Assist Manager BuilderGroup',

        -- Land Unit Builders T1 --
        'RNGAI ScoutLandBuilder',
        --'RNGAI LabLandBuilder', -- Remove to use queue
        'RNGAI TankLandBuilder Small',
        'RNGAI Land AntiAir Response',
        'RNGAI Reaction Tanks',
        'RNGAI T3 AttackLandBuilder Small',

        -- Land Unit Formers T1 --
        'RNGAI ScoutLandFormer',
        'RNGAI Land Mass Raid',
        'RNGAI Land FormBuilders',
        'RNGAI Land Response Formers',

        -- Land Factory Builders --
        'RNGAI Factory Builder Land',
        'RNGAI LandBuilder T1',
        'RNGAI LandBuilder T2',
        'RNGAI LandBuilder T3',
        'RNGAI LandBuilder T1 Islands',

        -- Air Factory Builders --
        'RNGAI Factory Builder Air',
        'RNGAI Air Staging Platform',

        -- Air Unit Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder T1',
        'RNGAI Air Builder T2',
        'RNGAI Air Builder T3',
        'RNGAI Air Builder T1 Ratio',
        'RNGAI Air Builder T2 Ratio',
        'RNGAI Air Builder T3 Ratio',
        'RNGAI TransportFactoryBuilders Small',

        -- Air Unit Formers --
        'RNGAI ScoutAirFormer',
        'RNGAI Air Platoon Builder',
        'RNGAI Air Response Formers',
        
        -- Defence Builders --
        'RNGAI Base Defenses',
        --'RNGAI Perimeter Defenses Small',
        'RNGAI T2 Defense FormBuilders',
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',

        -- Expansions --
        'RNGAI Engineer Naval Expansion Builders Small',
        'RNGAI Engineer Zone Expansion Builders',

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGAI SACU Builder',

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
            Tech1 = 45,
            Tech2 = 35,
            Tech3 = 25,
            SCU = 16,
        },
        FactoryCount = {
            Land = 20,
            Air = 3,
            Sea = 1,
            Gate = 2,
        },
        MassToFactoryValues = {
            T1LandValue = 4,
            T2LandValue = 10,
            T3LandValue = 23,
            T1AirValue = 3.5,
            T2AirValue = 10,
            T3AirValue = 25,
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
        if personality == 'RNGStandard' and mapSizeX < 1000 and mapSizeZ < 1000 or personality == 'RNGStandardcheat' and mapSizeX < 1000 and mapSizeZ < 1000 then
            --RNGLOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --RNGLOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandard'
        end
        return -1
    end,
}