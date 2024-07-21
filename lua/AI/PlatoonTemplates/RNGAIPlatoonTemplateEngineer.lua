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
    Name = 'EngineerStateT1RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1 , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateT123RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2 + categories.TECH3), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateT23RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH2 + categories.TECH3), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateT3RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH3, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateT3SACURNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateAeonT3SACURNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.AEON * categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateUEFT3SACURNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.UEF * categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateCybranT3SACURNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.CYBRAN * categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateSeraT3SACURNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.SERAPHIM * categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateT23RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH2 + categories.TECH3), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateT12RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2), 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerStateT3SACURNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH3 + categories.SUBCOMMANDER) - categories.ENGINEERSTATION - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'CommanderDummyRNG',
    Plan = 'DummyPlatoonAIRNG',
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
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.COMMAND, 1, 1, 'support', 'None' },
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
    Name = 'EngineerRepairRNG',
    Plan = 'RepairAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) , 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerReclaimWallsT1RNG',
    Plan = 'ReclaimUnitsAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1, 1, 1, 'support', 'None' }
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
    Name = 'EngineerStateUEFT2RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.UEF * categories.ENGINEER * categories.TECH2 - categories.ENGINEERSTATION - categories.FIELDENGINEER, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'EngineerBuilderCybranT2RNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.CYBRAN * categories.ENGINEER * categories.TECH2 - categories.ENGINEERSTATION, 1, 1, 'support', 'None' }
    },
}