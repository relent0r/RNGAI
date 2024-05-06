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
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE - categories.xsb3202, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL - categories.xsb3202, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * ( categories.DESTROYER + categories.BATTLESHIP ), 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.CRUISER, 0, 20, 'Artillery', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Attack Ranged T123',
    Plan = 'NavalRangedAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE - categories.xsb3202, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * ( categories.DESTROYER + categories.BATTLESHIP ), 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * ( categories.CRUISER + categories.xas0306 + categories.NUKE ), 1, 20, 'Artillery', 'GrowthFormation' },
    },
}