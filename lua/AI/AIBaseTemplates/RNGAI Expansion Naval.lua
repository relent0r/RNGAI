
BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Standard Expansion Naval',
    Builders = {
        'RNGAI Engineer Builder Naval Expansion',
        --'RNGAI Mass Builder Expansion',
        'RNGAI Naval Assist',
        'RNGAI Naval Factory Reclaim',

        -- Sea Builders --
        'RNGAI Factory Builder Sea',
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
            Sea = 6,
            Gate = 0,
        },
        EngineerCount = {
            Tech1 = 5,
            Tech2 = 2,
            Tech3 = 1,
            SCU = 0,
        },
        MassToFactoryValues = {
            T1Value = 7,
            T2Value = 25,
            T3Value = 45
        },
    },
    ExpansionFunction = function(aiBrain, location, markerType)
        if not aiBrain.RNG then
            return -1
        end
        if markerType ~= 'Naval Area' then
            return -1
        end
        local mapSizeX, mapSizeZ = GetMapSize()
        if mapSizeX < 1000 and mapSizeZ < 1000 then
            return 100, 'RNGStandard'
        end
    end,
}
