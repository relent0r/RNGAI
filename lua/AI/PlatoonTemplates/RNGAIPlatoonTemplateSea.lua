PlatoonTemplate {
    Name = 'RNGAI Sea Hunt',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.ANTINAVY, 1, 10, 'Attack', 'GrowthFormation' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Mass Raid T1',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 1, 10, 'Attack', 'GrowthFormation' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Mass Raid T1 Frigate',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.FRIGATE * categories.TECH1, 1, 20, 'Attack', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Intelli Sea Attack T1',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.FRIGATE * categories.TECH1, 1, 20, 'Attack', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Intelli Sea Attack T123',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE - categories.MOBILESONAR, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL - categories.MOBILESONAR, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * ( categories.DESTROYER + categories.BATTLESHIP ), 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.CRUISER, 0, 20, 'Artillery', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'T4ExperimentalNavalRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.EXPERIMENTAL * categories.NAVAL * categories.MOBILE - categories.INSIGNIFICANTUNIT, 1, 1, 'attack', 'none' }
    },
}