

-- Former Templates --

PlatoonTemplate {
    Name = 'RNGAI AntiAirHunt',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.GROUNDATTACK - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'none' },
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 0, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AntiAirFeeder',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.GROUNDATTACK - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AirScoutForm',
    Plan = 'AirScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AirScoutSingle',
    Plan = 'AirScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberAttack T1',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER * categories.TECH1, 1, 1, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberAttack',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY - categories.daa0206, 1, 100, 'Attack', 'GrowthFormation' },
        --Add an escort fighter squad?
        --{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Artillery', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI GunShipAttack',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.GROUNDATTACK - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'GrowthFormation' },
        --Add an escort fighter squad?
        --{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Artillery', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI MercyAttack',
    Plan = 'PlatoonMergeRNG',
    GlobalSquads = {
        { categories.daa0206 , 2, 3, 'Attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI TorpBomberAttack',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.ANTINAVY - categories.EXPERIMENTAL, 1, 50, 'Attack', 'GrowthFormation' },
    }
}



PlatoonTemplate {
    Name = 'T4ExperimentalAirRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.EXPERIMENTAL * categories.MOBILE - categories.SATELLITE, 1, 1, 'attack', 'none' },
    },
}

PlatoonTemplate {
    Name = 'T2AirMissile',
    FactionSquads = {
        Aeon = {
            { 'daa0206', 1, 4, 'Attack', 'none' },
        },
    }
}