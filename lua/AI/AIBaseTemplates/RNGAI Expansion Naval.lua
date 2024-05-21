
BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Standard Expansion Naval',
    Builders = {
        'RNGAI Engineer Builder Naval Expansion',
        --'RNGAI Mass Builder Expansion',
        'RNGAI Naval Assist',
        'RNGAI Naval Factory Reclaim',

        -- Sea Builders --
        'RNGAI Factory Builder Sea',
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
            Sea = 5,
            Gate = 0,
        },
        EngineerCount = {
            Tech1 = 5,
            Tech2 = 3,
            Tech3 = 1,
            SCU = 0,
        },
        MassToFactoryValues = {
            T1LandValue = 7,
            T2LandValue = 25,
            T3LandValue = 45,
            T1AirValue = 7,
            T2AirValue = 25,
            T3AirValue = 45,
            T1NavalValue = 5,
            T2NavalValue = 24,
            T3NavalValue = 45,
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
