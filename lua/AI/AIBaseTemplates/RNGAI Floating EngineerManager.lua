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
                'RNGAI Mass Builder Floating',
                'RNGAI T1 Reclaim Floating',
                'RNGAI Mass Storage Builder Floating',
                'RNGAI Engineer Zone Expansion Builders',
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
            T1LandValue = 0,
            T2LandValue = 0,
            T3LandValue = 0,
            T1AirValue = 0,
            T2AirValue = 0,
            T3AirValue = 0,
            T1NavalValue = 0,
            T2NavalValue = 0,
            T3NavalValue = 0,
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