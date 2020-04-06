PlatoonTemplate {
    Name = 'RNGAI Sea Hunt T1',
    Plan = 'NavalHuntAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 1, 10, 'Attack', 'GrowthFormation' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Mass Raid T1',
    Plan = 'MassRaidRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 1, 10, 'Attack', 'GrowthFormation' }
    },
}