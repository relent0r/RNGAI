PlatoonTemplate {
    Name = 'T1EngineerAssistRNG',
    Plan = 'ManagerEngineerAssistAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerAssistManagerT1RNG',
    Plan = 'PlatoonMergeRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerAssistManagerT2RNG',
    Plan = 'PlatoonMergeRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH2, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerAssistManagerT3RNG',
    Plan = 'PlatoonMergeRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH3, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T123EngineerFinishRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2 + categories.TECH3), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T123EngineerAssistRNG',
    Plan = 'ManagerEngineerAssistAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2 + categories.TECH3), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T23EngineerAssistRNG',
    Plan = 'ManagerEngineerAssistAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH2 + categories.TECH3), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T12EngineerAssistRNG',
    Plan = 'ManagerEngineerAssistAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T12EconAssistRNG',
    Plan = 'ManagerEngineerAssistAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T3SACUEngineerAssistRNG',
    Plan = 'ManagerEngineerAssistAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
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
    Name = 'CommanderInitializeRNG',
    Plan = 'CommanderInitializeAIRNG',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'CommanderStateMachineRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'CommanderAssistRNG',
    Plan = 'ManagerEngineerAssistAIRNG',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' },
    },
}

PlatoonTemplate {
    Name = 'EngineerBuilderT1RNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1 - categories.COMMAND , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerBuilderRNGMex',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1 - categories.COMMAND , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerBuilderT123RNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.COMMAND - categories.ENGINEERSTATION , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerBuilderT12RNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND - categories.ENGINEERSTATION , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerBuilderT23RNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH2 + categories.TECH3) - categories.COMMAND , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T2EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH2 - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T3EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH3 - categories.ENGINEERSTATION - categories.COMMAND , 1, 1, 'support', 'None' }
    },
}
PlatoonTemplate {
    Name = 'T23EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH2 + categories.TECH3) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}
PlatoonTemplate {
    Name = 'T3SACUEngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerRepairRNG',
    Plan = 'RepairAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'T1EngineerTransferRNG',
    Plan = 'TransferAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD, 1, 1, 'support', 'none' },
    },
}
PlatoonTemplate {
    Name = 'T2EngineerTransferRNG',
    Plan = 'TransferAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.ENGINEER * categories.TECH2 - categories.STATIONASSISTPOD, 1, 1, 'support', 'none' },
    },
}
PlatoonTemplate {
    Name = 'T3EngineerTransferRNG',
    Plan = 'TransferAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.ENGINEER * categories.TECH3 - categories.STATIONASSISTPOD, 1, 1, 'support', 'none' },
    },
}

PlatoonTemplate {
    Name = 'UEFT2EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.UEF * categories.ENGINEER * categories.TECH2, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'CybranT2EngineerBuilderRNG',
    Plan = 'EngineerBuildAIRNG',
    GlobalSquads = {
        { categories.CYBRAN * categories.ENGINEER * categories.TECH2 - categories.ENGINEERSTATION, 1, 1, 'support', 'None' }
    },
}