--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Standard Small.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Standard Large Expansion Area',
    Builders = {       
                -- Intel Builders --
                'RNGAI RadarBuilders Expansion',
                'RNGAI RadarUpgrade T1 Expansion',
                'RNGAI Engineer Transfer To Main From Expansion',
        
                -- Economy Builders --
                'RNGAI Energy Builder Expansion',
                'RNGAI Mass Builder Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                'RNGAI Engineering Support Builder',
                'RNGAI T1 Reclaim Builders Expansion',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI Land AA 2',
                'RNGAI LandBuilder T1',
                'RNGAI LandBuilder T2',
                --'RNGAI TankLandBuilder Small Expansions',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land FormBuilders Expansion Large',
        
                -- Land Factory Builders --
                'RNGAI Factory Builder Land Expansion',
        
                -- Land Factory Formers --
                'RNGAI T1 Upgrade Builders Expansion',
                'RNGAI TankLandBuilder Islands',
        
                -- Air Factory Builders --
                'RNGAI Factory Builder Air Expansion',
        
                -- Air Unit Builders T1 --
                'RNGAI ScoutAirBuilder',
                'RNGAI Air Builder T1',
        
                -- Air Unit Formers T1 --
                'RNGAI ScoutAirFormer',
                'RNGAI Air Platoon Builder',
        
                -- Defence Builders --
                'RNGAI Base Defenses',
                --'RNGAI Perimeter Defenses Small',
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
        --RNGLOG('Expansion Function for Large Expansion')
        if not aiBrain.RNG then
            return -1
        end
        if markerType ~= 'Large Expansion Area' then
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