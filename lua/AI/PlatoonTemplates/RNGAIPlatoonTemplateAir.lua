

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
    Plan = 'FeederPlatoon',
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

PlatoonTemplate {
    Name = 'RNGAIT1AirScoutBurst',
    FactionSquads = {
        UEF = {
            { 'uea0101', 1, 2, 'scout', 'None' },
        },
        Aeon = {
            { 'uaa0101', 1, 2, 'scout', 'None' },
        },
        Cybran = {
            { 'ura0101', 1, 2, 'scout', 'None' },
        },
        Seraphim = {
            { 'xsa0101', 1, 2, 'scout', 'None' },
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIT2FighterAeon',
    FactionSquads = {
        UEF = {
            { 'dea0202', 1, 1, 'Attack', 'None' },
        },
        Aeon = {
            { 'xaa0202', 1, 1, 'Attack', 'None' },
        },
        Cybran = {
            { 'dra0202', 1, 1, 'Attack', 'None' },
        },
        Seraphim = {
            { 'xsa0202', 1, 1, 'Attack', 'None' },
        },
    },
}

PlatoonTemplate { 
    Name = 'RNGAIT3AirAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 1, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0304', 1, 1, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}