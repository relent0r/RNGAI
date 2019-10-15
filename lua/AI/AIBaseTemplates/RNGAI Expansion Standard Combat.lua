--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Standard Small.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Standard Combat',
    Builders = {       
                -- Defence Builders --
                'RNGAI Base Defenses',
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
            T1Value = 8,
            T2Value = 20,
            T3Value = 30,
        },
        NoGuards = true,
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if markerType ~= 'Combat Zone' then
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