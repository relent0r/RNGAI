PlatoonTemplate {
    Name = 'AddToTMLPlatoonRNG',
    Plan = 'PlatoonMergeRNG',
    GlobalSquads = {
        { categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM * categories.TECH2 , 1, 300, 'attack', 'none' }
    },
}
PlatoonTemplate {
    Name = 'AddToSMLPlatoonRNG',
    Plan = 'PlatoonMergeRNG',
    GlobalSquads = {
        { categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) , 1, 300, 'attack', 'none' }
    },
}

PlatoonTemplate {
    Name = 'T4SatelliteExperimentalRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.SATELLITE, 1, 1, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'T3ArtilleryStructureRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.STRUCTURE * categories.ARTILLERY * (categories.TECH3 + categories.EXPERIMENTAL), 1, 1, 'artillery', 'none' }
    }
}

PlatoonTemplate {
    Name = 'T3NukeStructureRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), 1, 1, 'attack', 'none' }
    }
}

PlatoonTemplate {
    Name = 'T2TMLStructureRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.TACTICALMISSILEPLATFORM * categories.STRUCTURE * categories.TECH2, 1, 1, 'attack', 'none' }
    }
}

PlatoonTemplate {
    Name = 'T3OpticsStructureRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.AEON * categories.OPTICS * categories.STRUCTURE, 1, 1, 'attack', 'none' }
    }
}