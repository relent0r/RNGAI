PlatoonTemplate {
    Name = 'RNGAI Sea Hunt',
    Plan = 'NavalHuntAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE - categories.EXPERIMENTAL - categories.CARRIER, 1, 100, 'Attack', 'GrowthFormation' }
    },
}