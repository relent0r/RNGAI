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
                'RNGAI Mass Storage Builder',
                'RNGAI ExtractorUpgrades Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                'RNGAI Engineering Support Builder',
                'RNGAI T1 Reclaim Builders',
                'RNGAI T1 Assist Builders',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI TankLandBuilder Expansions',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land Mass Raid',
                'RNGAI Land FormBuilders Expansion',
        
                -- Land Factory Builders --
                'RNGAI Factory Builder Land',
        
                -- Land Factory Formers --
                'RNGAI T1 Upgrade Builders Expansion',
               
                -- Defence Builders --
                'RNGAI Base Defenses',
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
            Land = 2,
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
        if markerType ~= 'Expansion Area' then
            LOG('Expansion MarkerType is', markerType)
            return 0
        end
        
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        if not( personality == 'RNGStandard' or personality == 'RNGStandardcheat' ) then
            LOG('Expansion personality is', personality)
            return 0
        end

        local threatCutoff = 10 -- value of overall threat that determines where enemy bases are
        local distance = import('/lua/ai/AIUtilities.lua').GetThreatDistance( aiBrain, location, threatCutoff )
        LOG('Distance is ', distance)
        if not distance or distance > 1000 then
            LOG('Expansion return is 10')
            return 10
        elseif distance > 500 then
            LOG('Expansion return is 25')
            return 25
        elseif distance > 250 then
            LOG('Expansion return is 50')
            return 50
        else
            LOG('Expansion return is 100')
            return 100
        end
        LOG('Expansion return default 0')
        return 0
    end,
}