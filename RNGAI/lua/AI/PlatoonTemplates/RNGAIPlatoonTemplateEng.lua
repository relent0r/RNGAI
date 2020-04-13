-- Former Templates

PlatoonTemplate {
    Name = 'CommanderBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T2EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH2 - categories.ENGINEERSTATION, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T3EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH3 - categories.ENGINEERSTATION, 1, 1, 'support', 'None' }
    },
}
PlatoonTemplate {
    Name = 'T23EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH2 + categories.TECH3) - categories.ENGINEERSTATION, 1, 1, 'support', 'None' }
    },
}
PlatoonTemplate {
    Name = 'T3SACUEngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'CommanderBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerRepairRNG',
    Plan = 'RepairAI',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1, 1, 1, 'support', 'None' }
    },
}

