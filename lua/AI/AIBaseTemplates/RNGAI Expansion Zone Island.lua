--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Zone Island.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Zone Island',
    Builders = {       
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
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI TankLandBuilder Islands',
                'RNGAI Land AntiAir Response',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land FormBuilders Expansion',
                'RNGAI Land Response Formers',

                -- Land Factory Builders --
                --'RNGAI Factory Builder Land',
               
                -- Defence Builders --
                'RNGAI Base Defenses Expansion',
                'RNGAI T2 Defense FormBuilders',
                'RNGAI T2 Expansion TML',
                'RNGAI Shield Builder Expansion',
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
            Land = 8,
            Air = 1,
            Sea = 0,
            Gate = 1,
        },
        
        MassToFactoryValues = {
            T1LandValue = 4.5,
            T2LandValue = 14,
            T3LandValue = 22.5,
            T1AirValue = 5,
            T2AirValue = 15,
            T3AirValue = 22.5,
            T1NavalValue = 5,
            T2NavalValue = 15,
            T3NavalValue = 22.5,
        },
        NoGuards = true,
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if not aiBrain.RNG then
            return -1
        end
        if markerType ~= 'Zone Expansion' then
            return -1
        end
        if aiBrain.BuilderManagers['MAIN'].GraphArea then
            local NavUtils = import('/lua/sim/NavUtils.lua')
            local mainBaseLabel = aiBrain.BuilderManagers['MAIN'].GraphArea
            local label = NavUtils.GetLabel('Land', location)
            if mainBaseLabel ~= label then
                return 100
            end
        end
        return -1
    end,
}