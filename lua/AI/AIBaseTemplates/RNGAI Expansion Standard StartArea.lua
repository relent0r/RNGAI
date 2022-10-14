--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Standard Small.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Standard StartArea',
    Builders = {       
                -- Intel Builders --
                'RNGAI RadarBuilders Expansion',
                'RNGAI RadarUpgrade T1 Expansion',
        
                -- Economy Builders --
                'RNGAI Energy Builder Expansion',
                'RNGAI Mass Builder Expansion',
                --'RNGAI Mass Storage Builder',
                --'RNGAI ExtractorUpgrades Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                --'RNGAI Engineering Support Builder',
                'RNGAI T1 Reclaim Builders Expansion',
                --'RNGAI Assist Builders',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI TankLandBuilder Small Expansions',
                'RNGAI Reaction Tanks Expansion',
                'RNGAI TankLandBuilder Islands',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land Mass Raid',
                'RNGAI Land FormBuilders Expansion',
                'RNGAI Land Response Formers',
                'RNGAI Land AA 2',
        
                -- Land Factory Builders --
                'RNGAI Factory Builder Land Expansion',
        
                -- Land Factory Formers --
                'RNGAI T1 Upgrade Builders Expansion',
        
                -- Air Factory Builders --
                --'RNGAI Factory Builder Air',
        
                -- Air Unit Builders T1 --
                'RNGAI ScoutAirBuilder',
                'RNGAI Air Builder T1',
        
                -- Air Unit Formers T1 --
                'RNGAI ScoutAirFormer',
                'RNGAI Air Platoon Builder',
        
                -- Defence Builders --
                'RNGAI Base Defenses Expansion',
                'RNGAI Perimeter Defenses Expansions',
                'RNGAI T2 Defense FormBuilders',
                'RNGAI T2 Expansion TML',
                'RNGAI Shield Builder Expansion',
		},
    NonCheatBuilders = { },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 8,
            Tech2 = 4,
            Tech3 = 2,
            SCU = 0,
        },
        
        FactoryCount = {
            Land = 5,
            Air = 1,
            Sea = 0,
            Gate = 0,
        },
        
        MassToFactoryValues = {
            T1Value = 6,
            T2Value = 15,
            T3Value = 28,
        },
        NoGuards = true,
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        --RNGLOG('Expansion Function for Start Location')
        if not aiBrain.RNG then
            return -1
        end
        if markerType ~= 'Start Location' then
            --RNGLOG('* AI-RNG: Expansion MarkerType is', markerType)
            return -1
        end
        local spamBaseCheck
        local mapSizeX, mapSizeZ = GetMapSize()
        local threatCutoff = 10 -- value of overall threat that determines where enemy bases are
        local distance = import('/lua/ai/AIUtilities.lua').GetThreatDistance( aiBrain, location, threatCutoff )
        if mapSizeX < 1000 and mapSizeZ < 1000 then
            spamBaseCheck = false
        else
            spamBaseCheck = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').ExpansionSpamBaseLocationCheck(aiBrain, location)
        end
        --RNGLOG('* AI-RNG: Distance is ', distance)
        if not distance or distance > 1000 and not spamBaseCheck then
            --RNGLOG('* AI-RNG: Expansion return is 10')
            return 100
        elseif distance > 500 and not spamBaseCheck then
            --RNGLOG('* AI-RNG: Expansion return is 25')
            return 50
        elseif distance > 250 and not spamBaseCheck then
            --RNGLOG('* AI-RNG: Expansion return is 50')
            return 25
        elseif not spamBaseCheck then
            --RNGLOG('* AI-RNG: Expansion return is 100')
            return 10
        end
        --RNGLOG('* AI-RNG: Expansion return default 0')
        return -1
    end,
}