

AI = {
    Name = "RNGAI",
    Version = "1",
    AIList = {
        {
            key = 'RNGStandard',
            name = "<LOC RNG_0001>AI: RNG Standard",
            requiresNavMesh = true,
            rating = 600,
            ratingCheatMultiplier = 1.0,
            ratingBuildMultiplier = 1.0,
            ratingOmniBonus = 0.0,
            ratingMapMultiplier = {
                [256] = 0.75,   -- 5x5
                [512] = 1.0,   -- 10x10
                [1024] = 1.1,  -- 20x20
                [2048] = 1.1, -- 40x40
                [4096] = 0.6,  -- 80x80
            }
        },
        {
            key = 'RNGStandardExperimental',
            name = "<LOC RNG_0002>AI: RNG Standard Experimental",
            requiresNavMesh = true,
            rating = 400,
            ratingCheatMultiplier = 1.0,
            ratingBuildMultiplier = 1.0,
            ratingOmniBonus = 0.0,
            ratingMapMultiplier = {
                [256] = 0.75,   -- 5x5
                [512] = 1.0,   -- 10x10
                [1024] = 1.1,  -- 20x20
                [2048] = 1.1, -- 40x40
                [4096] = 0.6,  -- 80x80
            }
        },
        --{
        --   key = 'RNGStandardnull',
        --    name = "<LOC RNG_0001>AI: RNG Standardnull",
        --},
    },
    -- key names must have the word "cheat" included, or we won't get omniview
    CheatAIList = {
        {
            key = 'RNGStandardcheat',
            name = "<LOC RNG_0003>AIx: RNG Standard",
            requiresNavMesh = true,
            rating = 600,
            ratingCheatMultiplier = 1.2,
            ratingBuildMultiplier = 1.2,
            ratingOmniBonus = 50.0,
            ratingMapMultiplier = {
                [256] = 0.75,   -- 5x5
                [512] = 1.0,   -- 10x10
                [1024] = 1.1,  -- 20x20
                [2048] = 1.1, -- 40x40
                [4096] = 0.6,  -- 80x80
            }
        },
        {
            key = 'RNGStandardExperimentalcheat',
            name = "<LOC RNG_0004>AIx: RNG Standard Experimental",
            requiresNavMesh = true,
            rating = 400,
            ratingCheatMultiplier = 1.2,
            ratingBuildMultiplier = 1.2,
            ratingOmniBonus = 50.0,
            ratingMapMultiplier = {
                [256] = 0.75,   -- 5x5
                [512] = 1.0,   -- 10x10
                [1024] = 1.1,  -- 20x20
                [2048] = 1.1, -- 40x40
                [4096] = 0.6,  -- 80x80
            }
        },
        --{
        --   key = 'RNGStandardnullcheat',
        --    name = "<LOC RNG_0003>AIx: RNG Standardnull",
       --},
    },
}