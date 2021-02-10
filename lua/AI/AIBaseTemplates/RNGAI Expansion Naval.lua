
BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Standard Expansion Naval',
    Builders = {
        'RNGAI Engineer Builder Expansion',
        'RNGAI Mass Builder Expansion',
        'RNGAI Naval Assist',

        -- Sea Builders --
        'RNGAI Factory Builder Sea Large',
        'RNGAI Sea Upgrade Builders',
        'RNGAI T12 Perimeter Defenses Naval',

        -- Sea Unit Builders
        'RNGAI SonarBuilders',
        'RNGAI SonarUpgrade',
        -- Sea Unit Formers
        'RNGAI Sea Builders T1',
        'RNGAI Sea Builders T23',
        -- Sea Formers --
        'RNGAI Sea Formers',
        'RNGAI Mass Hunter Sea Formers',
    },

    BaseSettings = {
        FactoryCount = {
            Land = 0,
            Air = 0,
            Sea = 8,
            Gate = 0,
        },
        EngineerCount = {
            Tech1 = 4,
            Tech2 = 3,
            Tech3 = 1,
            SCU = 0,
        },
        MassToFactoryValues = {
            T1Value = 4,
            T2Value = 11,
            T3Value = 19
        },
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if not aiBrain.RNG then
            return -1
        end
        if markerType ~= 'Naval Area' then
            return -1
        end
        return 100, 'RNGStandard'
    end,
}
