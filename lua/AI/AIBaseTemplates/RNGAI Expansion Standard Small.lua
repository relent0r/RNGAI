--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Standard Small.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Standard Small',
    Builders = {       
                -- Intel Builders --
                'RNGAI RadarBuilders',
                'RNGAI RadarUpgrade T1 Expansion',
        
                -- Economy Builders --
                'RNGAI Energy Builder Expansion',
                'RNGAI Mass Builder Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                'RNGAI T1 Reclaim Builders Expansion',
                'RNGAI T1 Assist Builders',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI TankLandBuilder Small Expansions',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land FormBuilders Expansion',

                -- Air Unit Formers --
                'RNGAI Air Platoon Builder',
        
                -- Land Factory Builders --
                --'RNGAI Factory Builder Land',
        
                -- Land Factory Formers --
                'RNGAI T1 Upgrade Builders Expansion',
               
                -- Defence Builders --
                'RNGAI Base Defenses Expansion',
                'RNGAI T1 Perimeter Defenses',
                'RNGAI T2 Expansion TML',
		},
    NonCheatBuilders = { },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 6,
            Tech2 = 4,
            Tech3 = 2,
            SCU = 0,
        },
        
        FactoryCount = {
            Land = 3,
            Air = 0,
            Sea = 0,
            Gate = 0,
        },
        
        MassToFactoryValues = {
            T1Value = 6,
            T2Value = 15,
            T3Value = 22.5,
        },
        NoGuards = true,
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if not aiBrain.RNG then
            return -1
        end
        if markerType ~= 'Expansion Area' then
            --LOG('* AI-RNG: Expansion MarkerType is', markerType)
            return -1
        end
        
        local threatCutoff = 10 -- value of overall threat that determines where enemy bases are
        local distance = import('/lua/ai/AIUtilities.lua').GetThreatDistance( aiBrain, location, threatCutoff )
        --LOG('* AI-RNG: Distance is ', distance)
        if not distance or distance > 1000 then
            --LOG('* AI-RNG: Expansion return is 10')
            return 10
        elseif distance > 500 then
            --LOG('* AI-RNG: Expansion return is 25')
            return 25
        elseif distance > 250 then
            --LOG('* AI-RNG: Expansion return is 50')
            return 50
        else
            --LOG('* AI-RNG: Expansion return is 100')
            return 100
        end
        --LOG('* AI-RNG: Expansion return default 0')
        return -1
    end,
}