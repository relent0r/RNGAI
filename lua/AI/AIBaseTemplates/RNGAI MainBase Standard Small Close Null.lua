--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

local MABC = import('/lua/editor/MarkerBuildConditions.lua')

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small Close Null',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Small Close',

        -- ACU Other Builders --
        'RNGAI ACU Build Assist',
        'RNGAI ACU Structure Builders',
        --'RNGAI Test PD',
        'RNGAI ACU Enhancements Gun',
        'RNGAI Engineer Builder',
        'RNGAI Factory Builder Sea',
        'RNGAI Land Upgrade Builders',

        -- Mass Building
        'RNGAI Mass Builder',
        -- Energy Building
        'RNGAI Energy Builder',

        -- Sea Unit Builders
        'RNGAI Sea Builders T1',
        'RNGAI Sea Formers',
        'RNGAI Mass Hunter Sea Formers',
 
        -- Air Factory Formers --
        'RNGAI Air Upgrade Builders',

        -- Air Unit Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder T1',
        'RNGAI Air Builder T2',
        'RNGAI Air Builder T3',
        'RNGAI TransportFactoryBuilders',

        -- Air Unit Formers --
        'RNGAI ScoutAirFormer',
        'RNGAI Air Platoon Builder',
        'RNGAI Air Response Formers T1',
        
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
            Land = 12,
            Air = 4,
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
        if personality == 'RNGStandardnull' and mapSizeX < 1000 and mapSizeZ < 1000 or personality == 'RNGStandardcheatnull' and mapSizeX < 1000 and mapSizeZ < 1000 then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            if MABC.CanBuildOnMassLessThanDistance(aiBrain, 'MAIN', 10, -500, 0, 0, 'AntiSurface', 1) then
                --LOG('* AI-RNG: ACU has close mexes')
                return 1000, 'RNGStandardnull'
            else 
                --LOG('* AI-RNG: ACU has distant mexes')
                return -1
            end
        end
        return -1
    end,
}