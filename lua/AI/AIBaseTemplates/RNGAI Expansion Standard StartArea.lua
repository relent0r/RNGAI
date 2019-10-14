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
                'RNGAI RadarBuilders',
                'RNGAI RadarUpgrade T1 Expansion',
        
                -- Economy Builders --
                'RNGAI Energy Builder Expansion',
                'RNGAI Mass Builder Expansion',
                'RNGAI MassStorageBuilder',
                'RNGAI ExtractorUpgrades Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                'RNGAI Engineering Support Builder',
                'RNGAI T1 Reclaim Assist Builders',
                'RNGAI T2 Reclaim Assist Builders',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI TankLandBuilder',
                'RNGAI T1 Reaction Tanks',
                'RNGAI T2 TankLandBuilder',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land FormBuilders',
        
                -- Land Factory Builders --
                'RNGAI Factory Builder Land',
        
                -- Land Factory Formers --
                'RNGAI T1 Upgrade Builders Expansion',
        
                -- Air Factory Builders --
                'RNGAI Factory Builder Air',
        
                -- Air Unit Builders T1 --
                'RNGAI ScoutAirBuilder',
                'RNGAI Air Builder',
        
                -- Air Unit Formers T1 --
                'RNGAI ScoutAirFormer',
                'RNGAI Air Platoon Builder',
        
                -- Defence Builders --
                'RNGAI Base Defenses',
                'RNGAI T1 Perimeter Defenses',
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
            Land = 4,
            Air = 1,
            Sea = 0,
            Gate = 0,
        },
        
        MassToFactoryValues = {
            T1Value = 8,
            T2Value = 20,
            T3Value = 30,
        },
        NoGuards = true,
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if markerType ~= 'Start Location' then
            LOG('Expansion MarkerType is', markerType)
            return 0
        end
        
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        if not( personality == 'RNGStandard' or personality == 'RNGStandardCheat' ) then
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