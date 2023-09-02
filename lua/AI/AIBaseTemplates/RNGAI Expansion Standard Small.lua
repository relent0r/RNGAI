--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Standard Small.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Standard Small',
    Builders = {       
                -- ACU Builders --
                'RNGAI ACU Build Assist',
                
                -- Intel Builders --
                'RNGAI RadarBuilders Expansion',
                'RNGAI RadarUpgrade T1 Expansion',
        
                -- Economy Builders --
                'RNGAI Energy Builder Expansion',
                'RNGAI Mass Builder Expansion',
                'RNGAI Mass Storage Builder Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                'RNGAI T1 Reclaim Builders Expansion',
                'RNGAI Assist Builders',
                'RNGAI Engineer Transfer To Main From Expansion',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI LandBuilder T1',
                'RNGAI LandBuilder T2',
                'RNGAI LandBuilder T3',
                'RNGAI TankLandBuilder Islands',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land FormBuilders Expansion',

                -- Air Unit Formers --
                'RNGAI Air Platoon Builder',
                
                -- Land Factory Builders --
                'RNGAI Factory Builder Land Expansion',
        
                -- Land Factory Formers --
                'RNGAI T1 Upgrade Builders Expansion',
               
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
            Tech1 = 15,
            Tech2 = 8,
            Tech3 = 3,
            SCU = 0,
        },
        
        FactoryCount = {
            Land = 3,
            Air = 0,
            Sea = 0,
            Gate = 0,
        },
        
        MassToFactoryValues = {
            T1LandValue = 6,
            T2LandValue = 15,
            T3LandValue = 28,
            T1AirValue = 6,
            T2AirValue = 15,
            T3AirValue = 28,
            T1NavalValue = 6,
            T2NavalValue = 15,
            T3NavalValue = 28,
        },
        NoGuards = true,
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if not aiBrain.RNG then
            return -1
        end
        if markerType ~= 'Expansion Area' then
            --RNGLOG('* AI-RNG: Expansion MarkerType is', markerType)
            return -1
        end
        
        local threatCutoff = 10 -- value of overall threat that determines where enemy bases are
        local distance = import('/lua/ai/AIUtilities.lua').GetThreatDistance( aiBrain, location, threatCutoff )
        --RNGLOG('* AI-RNG: Distance is ', distance)
        if not distance or distance > 1000 then
            --RNGLOG('* AI-RNG: Expansion return is 10')
            return 10
        elseif distance > 500 then
            --RNGLOG('* AI-RNG: Expansion return is 25')
            return 25
        elseif distance > 250 then
            --RNGLOG('* AI-RNG: Expansion return is 50')
            return 50
        else
            --RNGLOG('* AI-RNG: Expansion return is 100')
            return 100
        end
        --RNGLOG('* AI-RNG: Expansion return default 0')
        return -1
    end,
}