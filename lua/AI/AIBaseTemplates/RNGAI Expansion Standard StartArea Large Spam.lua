--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Standard Small.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Standard StartArea Large Spam',
    Builders = {       
                -- Intel Builders --
                'RNGAI RadarBuilders Expansion',
                'RNGAI RadarUpgrade T1 Expansion',
        
                -- Economy Builders --
                'RNGAI Energy Builder Expansion',
                'RNGAI Mass Builder Expansion',
                'RNGAI Mass Storage Builder Expansion',
                --'RNGAI ExtractorUpgrades Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                --'RNGAI Engineering Support Builder',
                'RNGAI T1 Reclaim Builders Expansion',
                'RNGAI Assist Builders',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI LandBuilder T1',
                'RNGAI LandBuilder T2',
                'RNGAI LandBuilder T3',
                'RNGAI Reaction Tanks Expansion',
                'RNGAI Land AA 2',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land Mass Raid',
                'RNGAI Land FormBuilders Expansion Large',
                'RNGAI Land Response Formers',
                'RNGAI Air Response Formers',
        
                -- Land Factory Builders --
                'RNGAI Factory Builder Unmarked Spam',
                --'RNGAI Factory Builder Land',
        
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
                --'RNGAI Perimeter Defenses Small',
                --'RNGAI T2 Expansion TML',
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
            Land = 10,
            Air = 2,
            Sea = 0,
            Gate = 0,
        },
        
        MassToFactoryValues = {
            T1LandValue = 6,
            T2LandValue = 15,
            T3LandValue = 22.5,
            T1AirValue = 6,
            T2AirValue = 15,
            T3AirValue = 22.5,
            T1NavalValue = 6,
            T2NavalValue = 15,
            T3NavalValue = 22.5,
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
            return -1
        else
            spamBaseCheck = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').ExpansionSpamBaseLocationCheck(aiBrain, location)
        end
        --RNGLOG('* AI-RNG: Distance is ', distance)
        --RNGLOG('* AI-RNG: Position is ', repr(location))
        if distance > 500 and spamBaseCheck then
            --RNGLOG('* AI-RNG: Start Area Spam Expansion return is 25')
            return 50
        elseif distance > 250 and spamBaseCheck then
            --RNGLOG('* AI-RNG: Start Area Spam Expansion return is 50')
            return 75
        elseif spamBaseCheck then
            --RNGLOG('* AI-RNG: Start Area Spam Expansion return is 100')
            return 100
        end
        --RNGLOG('* AI-RNG: Expansion return default 0')
        return -1
    end,
}