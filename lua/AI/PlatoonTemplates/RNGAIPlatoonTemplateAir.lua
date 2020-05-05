

-- Former Templates --

PlatoonTemplate {
    Name = 'RNGAI AntiAirHunt',
    Plan = 'AirHuntAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 3, 100, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1AirScoutForm',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * categories.TECH1, 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T3AirScoutForm',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * categories.TECH3, 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AntiAir BaseGuard',
    Plan = 'GuardBaseRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 2, 50, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI Bomber BaseGuard',
    Plan = 'GuardBaseRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.daa0206 - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 1, 50, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI Gunship BaseGuard',
    Plan = 'GuardBaseRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.GROUNDATTACK * (categories.TECH1 + categories.TECH2) - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 1, 50, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberAttack',
    Plan = 'StrikeForceAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY - categories.daa0206, 1, 100, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI GunShipAttack',
    Plan = 'StrikeForceAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.GROUNDATTACK - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberEnergyAttack',
    Plan = 'StrikeForceAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY - categories.daa0206, 1, 5, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI MercyAttack',
    Plan = 'MercyAIRNG',
    GlobalSquads = {
        { categories.daa0206 , 2, 3, 'Attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI TorpBomberAttack',
    Plan = 'AirHuntAI',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.ANTINAVY - categories.EXPERIMENTAL, 1, 50, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'T2AirMissile',
    FactionSquads = {
        Aeon = {
            { 'daa0206', 1, 4, 'attack', 'none' },
        },
    }
}
PlatoonTemplate {
    Name = 'RNGAIFighterGroup',
    FactionSquads = {
        UEF = {
            { 'uea0102', 1, 3, 'attack', 'GrowthFormation' }
        },
        Aeon = {
            { 'uaa0102', 1, 3, 'attack', 'GrowthFormation' }
        },
        Cybran = {
            { 'ura0102', 1, 3, 'attack', 'GrowthFormation' }
        },
        Seraphim = {
            { 'xsa0102', 1, 3, 'attack', 'GrowthFormation' }
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIT1AirQueue',
    FactionSquads = {
        UEF = {
            { 'uea0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uea0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Aeon = {
            { 'uaa0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uaa0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Cybran = {
            { 'ura0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'ura0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
            { 'xra0105', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Gunship
            
        },
        Seraphim = {
            { 'xsa0102', 1, 1, 'attack', 'GrowthFormation' }, -- T1 Fighter
            { 'xsa0103', 1, 2, 'attack', 'GrowthFormation' }, -- T1 Bomber
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIT2AirQueue',
    FactionSquads = {
        UEF = {
            { 'dea0202', 1, 2, 'attack', 'None' }, -- FighterBomber
            { 'uea0203', 1, 2, 'attack', 'None' }, -- Gunship
        },
        Aeon = {
            { 'xaa0202', 1, 1, 'attack', 'None' },-- Fighter
            { 'xaa0202', 1, 2, 'attack', 'None' },-- Gunship
        },
        Cybran = {
            { 'dra0202', 1, 2, 'attack', 'None' },-- FighterBomber
            { 'dra0202', 1, 2, 'attack', 'None' },-- Gunship
        },
        Seraphim = {
            { 'xsa0202', 1, 2, 'attack', 'None' },-- FighterBomber
            { 'xsa0202', 1, 2, 'attack', 'None' }, -- Gunship
        },
    },
}

PlatoonTemplate {
    Name = 'RNGAIT2FighterAeon',
    FactionSquads = {
        UEF = {
            { 'dea0202', 1, 1, 'attack', 'None' },
        },
        Aeon = {
            { 'xaa0202', 1, 1, 'attack', 'None' },
        },
        Cybran = {
            { 'dra0202', 1, 1, 'attack', 'None' },
        },
        Seraphim = {
            { 'xsa0202', 1, 1, 'attack', 'None' },
        },
    },
}

PlatoonTemplate { Name = 'RNGAIT3AirResponse',
    FactionSquads = {
        UEF = {
            { 'uea0303', 1, 2, 'Attack', 'none' },      -- Air Superiority Fighter
         },
        Aeon = {
            { 'uaa0303', 1, 2, 'Attack', 'none' },      -- Air Superiority Fighter
        },
        Cybran = {
            { 'ura0303', 1, 2, 'Attack', 'none' },      -- Air Superiority Fighter
        },
        Seraphim = {
            { 'xsa0303', 1, 2, 'attack', 'none' },      -- Air Superiority Fighter
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT3AirAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 1, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0304', 2, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 3, 'attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0304', 1, 1, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0303', 1, 2, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}