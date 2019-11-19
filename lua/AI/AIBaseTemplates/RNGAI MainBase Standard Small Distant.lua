--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

local MABC = import('/lua/editor/MarkerBuildConditions.lua')

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small Distant',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Small Distant',

        -- ACU Other Builders --
        'RNGAI ACU Build Assist',
        'RNGAI ACU Structure Builders',
        --'RNGAI Test PD',

        -- Intel Builders --
        'RNGAI RadarBuilders',
        'RNGAI RadarUpgrade T1',

        -- Economy Builders --
        'RNGAI Energy Builder',
        'RNGAI Energy Storage Builder',
        'RNGAI Mass Builder',
        'RNGAI Mass Storage Builder',
        'RNGAI Hydro Builder',
        'RNGAI ExtractorUpgrades',

        -- Engineer Builders --
        'RNGAI Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        'RNGAI T1 Assist Builders',
        'RNGAI T2 Assist Builders',
        'RNGAI Energy Production Reclaim',

        -- Land Unit Builders T1 --
        'RNGAI ScoutLandBuilder',
        'RNGAI LabLandBuilder',
        'RNGAI TankLandBuilder',
        'RNGAI Land AA 2',
        'RNGAI T1 Reaction Tanks',
        'RNGAI T2 TankLandBuilder',
        'RNGAI T3 AttackLandBuilder',

        -- Land Unit Formers T1 --
        'RNGAI ScoutLandFormer',
        'RNGAI Land FormBuilders',
        'RNGAI Mass Hunter Labs FormBuilders',
        'RNGAI Land FormBuilders AntiMass',
        'RNGAI Land Response Formers',

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
        'RNGAI TransportFactoryBuilders',

        -- Air Unit Formers --
        'RNGAI ScoutAirFormer',
        'RNGAI Air Platoon Builder',
        'RNGAI Air Response Formers T1',

        -- Defence Builders --
        'RNGAI Base Defenses',
        'RNGAI T1 Perimeter Defenses',
        'RNGAI T2 Defense FormBuilders',

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
            Land = 12,
            Air = 4,
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
            if MABC.CanBuildOnMassLessThanDistance(aiBrain, 'MAIN', 10, -500, 0, 0, 'AntiSurface', 1) then
                LOG('ACU has close mexes')
                return -1
            else
                LOG('ACU has distant mexes')
                return 1000, 'RNGStandard'
            end
        end
        return -1
    end,
}