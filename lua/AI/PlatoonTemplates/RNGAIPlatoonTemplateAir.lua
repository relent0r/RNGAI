

-- Former Templates --

PlatoonTemplate {
    Name = 'RNGAI AntiAirHunt',
    Plan = 'AirHuntAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.GROUNDATTACK - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 1, 100, 'Attack', 'none' },
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 0, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AntiAirLockdown',
    Plan = 'AirHuntAI',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.GROUNDATTACK - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 3, 100, 'Attack', 'none' },
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 0, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AirScoutForm',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AirScoutSingle',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberAttack T1',
    Plan = 'BomberStrikeAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER * categories.TECH1, 1, 1, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberAttack',
    Plan = 'BomberStrikeAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY - categories.daa0206, 1, 100, 'Attack', 'GrowthFormation' },
        --Add an escort fighter squad?
        --{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Artillery', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI GunShipAttack',
    Plan = 'GunshipStrikeAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.GROUNDATTACK - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'GrowthFormation' },
        --Add an escort fighter squad?
        --{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Artillery', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberEnergyAttack',
    Plan = 'BomberStrikeAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY - categories.daa0206, 1, 5, 'Attack', 'GrowthFormation' },
        --Add an escort fighter squad?
        --{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Artillery', 'GrowthFormation' },
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
    Plan = 'AirHuntAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.ANTINAVY - categories.EXPERIMENTAL, 1, 50, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'T4ExperimentalAirRNG',
    Plan = 'ExperimentalAIHubRNG',
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
            { 'uea0101', 1, 3, 'scout', 'None' },
        },
        Aeon = {
            { 'uaa0101', 1, 3, 'scout', 'None' },
        },
        Cybran = {
            { 'ura0101', 1, 3, 'scout', 'None' },
        },
        Seraphim = {
            { 'xsa0101', 1, 3, 'scout', 'None' },
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIT3ScoutBurst',
    FactionSquads = {
        UEF = {
            { 'uea0302', 1, 3, 'scout', 'none' },      -- Scout
        },
        Aeon = {
            { 'uaa0302', 1, 3, 'scout', 'None' },
        },
        Cybran = {
            { 'ura0302', 1, 3, 'scout', 'None' },
        },
        Seraphim = {
            { 'xsa0302', 1, 3, 'scout', 'None' },
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIFighterGroup',
    FactionSquads = {
        UEF = {
            { 'uea0102', 1, 2, 'Attack', 'None' },
            { 'uea0101', 1, 1, 'scout', 'None' },
        },
        Aeon = {
            { 'uaa0102', 1, 2, 'Attack', 'None' },
            { 'uaa0101', 1, 1, 'scout', 'None' },
        },
        Cybran = {
            { 'ura0102', 1, 2, 'Attack', 'None' },
            { 'ura0101', 1, 1, 'scout', 'None' },
        },
        Seraphim = {
            { 'xsa0102', 1, 2, 'Attack', 'None' },
            { 'xsa0101', 1, 1, 'scout', 'None' },
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIFighterGroupT2',
    FactionSquads = {
        UEF = {
            { 'uea0101', 1, 1, 'scout', 'None' },
            { 'uea0102', 1, 2, 'Attack', 'None' }, -- T1 Fighter
            { 'dea0202', 1, 1, 'Attack', 'None' } -- T2 FighterBomber
        },
        Aeon = {
            { 'uaa0101', 1, 1, 'scout', 'None' },
            { 'xaa0202', 1, 2, 'Attack', 'None' }, -- T2 Fighter
        },
        Cybran = {
            { 'ura0101', 1, 1, 'scout', 'None' },
            { 'ura0102', 1, 2, 'Attack', 'None' }, -- T1 Fighter
            { 'dra0202', 1, 1, 'Attack', 'None' } -- T2 FighterBomber
        },
        Seraphim = {
            { 'xsa0101', 1, 1, 'scout', 'None' },
            { 'xsa0102', 1, 2, 'Attack', 'None' }, -- T1 Fighter
            { 'xsa0202', 1, 1, 'Attack', 'None' } -- T2 FighterBomber
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIT1AirQueue',
    FactionSquads = {
        UEF = {
            { 'uea0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uea0101', 1, 1, 'scout', 'None' },
            { 'uea0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Aeon = {
            { 'uaa0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uaa0101', 1, 1, 'scout', 'None' },
            { 'uaa0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Cybran = {
            { 'ura0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'ura0101', 1, 1, 'scout', 'None' },
            { 'ura0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
            { 'xra0105', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Gunship
            
        },
        Seraphim = {
            { 'xsa0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'xsa0101', 1, 1, 'scout', 'None' },
            { 'xsa0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIT2AirQueue',
    FactionSquads = {
        UEF = {
            { 'dea0202', 1, 2, 'Attack', 'None' }, -- FighterBomber
            { 'uea0203', 1, 2, 'Attack', 'None' }, -- Gunship
        },
        Aeon = {
            { 'xaa0202', 1, 1, 'Attack', 'None' },-- Fighter
            { 'uaa0203', 1, 2, 'Attack', 'None' },-- Gunship
        },
        Cybran = {
            { 'dra0202', 1, 2, 'Attack', 'None' },-- FighterBomber
            { 'ura0203', 1, 2, 'Attack', 'None' },-- Gunship
        },
        Seraphim = {
            { 'xsa0202', 1, 2, 'Attack', 'None' },-- FighterBomber
            { 'xsa0203', 1, 2, 'Attack', 'None' }, -- Gunship
        },
    },
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

PlatoonTemplate { Name = 'RNGAIT3AirResponse',
    FactionSquads = {
        UEF = {
            { 'uea0303', 1, 2, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
         },
        Aeon = {
            { 'uaa0303', 1, 2, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
        },
        Cybran = {
            { 'ura0303', 1, 2, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
        },
        Seraphim = {
            { 'xsa0303', 1, 2, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
        },
    }
}

PlatoonTemplate { 
    Name = 'RNGAIT3AirQueue',
    FactionSquads = {
        UEF = {
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 4, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 1, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 4, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0304', 2, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 4, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0304', 1, 1, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}

PlatoonTemplate { 
    Name = 'RNGAIT3AirAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 2, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 1, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 2, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 2, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0304', 1, 1, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 2, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}