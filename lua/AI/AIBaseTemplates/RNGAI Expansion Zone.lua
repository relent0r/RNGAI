--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI Expansion Zone.lua
    Author  :   relentless
    Summary :
        Expansion Template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Expansion Zone',
    Builders = {       
                -- Intel Builders --
                'RNGAI RadarBuilders Expansion',
                'RNGAI RadarUpgrade T1 Expansion',
        
                -- Economy Builders --
                'RNGAI Energy Builder Expansion',
                'RNGAI Mass Builder Expansion',
        
                -- Engineer Builders --
                'RNGAI Engineer Builder Expansion',
                'RNGAI T1 Reclaim Builders Expansion',
                'RNGAI Assist Builders',
        
                -- Land Unit Builders T1 --
                'RNGAI ScoutLandBuilder',
                'RNGAI Reaction Tanks Expansion',
                'RNGAI LandBuilder T1',
                'RNGAI LandBuilder T2',
                'RNGAI LandBuilder T3',
        
                -- Land Unit Formers T1 --
                'RNGAI ScoutLandFormer',
                'RNGAI Land FormBuilders Expansion',
                'RNGAI Land Response Formers',

                -- Land Factory Builders --
                --'RNGAI Factory Builder Land',
        
                -- Land Factory Formers --
                'RNGAI T1 Upgrade Builders Expansion',
               
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
            Land = 3,
            Air = 0,
            Sea = 0,
            Gate = 0,
        },
        
        MassToFactoryValues = {
            T1LandValue = 5,
            T2LandValue = 15,
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
        local EnemyIndex
        local OwnIndex = aiBrain:GetArmyIndex()
        local EnemyArmy = aiBrain:GetCurrentEnemy()
        if EnemyArmy then
            EnemyIndex = EnemyArmy:GetArmyIndex()
        end
        if aiBrain.BuilderManagers['MAIN'].GraphArea then
            local NavUtils = import('/lua/sim/NavUtils.lua')
            local mainBaseLabel = aiBrain.BuilderManagers['MAIN'].GraphArea
            LOG('Non Island Main base has GraphArea of '..mainBaseLabel)
            local label = NavUtils.GetLabel('Land', location)
            LOG('Non Island Expansion GraphArea is '..label)
            if mainBaseLabel == label then
                LOG('Return 100 priority')
                return 100
            end
        end
        return -1
    end,
}