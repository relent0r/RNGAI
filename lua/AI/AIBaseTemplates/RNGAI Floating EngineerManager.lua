--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Floating EngineerManager.lua
    Author  :   relentless
    Summary :
        This is a custom base template for floating engineers. 
        Which are engineers that have gone outside a certain radius and are no longer efficiently able to return to base.
]]

BaseBuilderTemplate {
    BaseTemplateName = 'FloatingBaseTemplate',
    Builders = {       
                'RNGAI Mass Builder Expansion',
                'RNGAI T1 Reclaim Builders Expansion',

		},
    NonCheatBuilders = { },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 100,
            Tech2 = 100,
            Tech3 = 100,
            SCU = 100,
        },
        
        FactoryCount = {
            Land = 0,
            Air = 0,
            Sea = 0,
            Gate = 0,
        },
        
        MassToFactoryValues = {
            T1Value = 0,
            T2Value = 0,
            T3Value = 0,
        },
        NoGuards = true,
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if not aiBrain.RNG then
            return -1
        end
        return -1
    end,
}