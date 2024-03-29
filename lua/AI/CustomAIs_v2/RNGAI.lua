

AI = {
    Name = "RNGAI",
    Version = "1",
    AIList = {
        {
            key = 'RNGStandard',
            name = "<LOC RNG_0001>AI: RNG Standard",
            requiresNavMesh = true,
        },
        {
            key = 'RNGStandardExperimental',
            name = "<LOC RNG_0002>AI: RNG Standard Experimental",
            requiresNavMesh = true,
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
        },
        {
            key = 'RNGStandardExperimentalcheat',
            name = "<LOC RNG_0004>AIx: RNG Standard Experimental",
            requiresNavMesh = true,
        },
        --{
        --   key = 'RNGStandardnullcheat',
        --    name = "<LOC RNG_0003>AIx: RNG Standardnull",
       --},
    },
}