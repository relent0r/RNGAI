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
        { categories.ARTILLERY * categories.STRUCTURE * categories.TECH3, 1, 1, 'artillery', 'none' }
    }
}

PlatoonTemplate {
    Name = 'T3NukeStructureRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.ARTILLERY * categories.STRUCTURE * categories.TECH3, 1, 1, 'artillery', 'none' }
    }
}