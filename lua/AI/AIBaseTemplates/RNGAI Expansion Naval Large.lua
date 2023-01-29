
BaseBuilderTemplate {
    BaseTemplateName = 'RNGAI Standard Expansion Naval Large',
    Builders = {
        'RNGAI Engineer Builder Naval Expansion',
        --'RNGAI Mass Builder Expansion',
        'RNGAI Naval Assist',
        'RNGAI Naval Factory Reclaim',

        -- Sea Builders --
        'RNGAI Factory Builder Sea Large',
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
            Tech1 = 5,
            Tech2 = 3,
            Tech3 = 2,
            SCU = 0,
        },
        MassToFactoryValues = {
            T1LandValue = 7,
            T2LandValue = 19,
            T3LandValue = 28,
            T1AirValue = 7,
            T2AirValue = 19,
            T3AirValue = 28,
            T1NavalValue = 7,
            T2NavalValue = 19,
            T3NavalValue = 28,
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
        if mapSizeX > 1000 and mapSizeZ > 1000 then
            return 100, 'RNGStandard'
        end
    end,
}
