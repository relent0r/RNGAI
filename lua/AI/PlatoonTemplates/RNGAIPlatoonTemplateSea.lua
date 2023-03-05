PlatoonTemplate {
    Name = 'RNGAI Sea Hunt',
    Plan = 'NavalHuntAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.ANTINAVY, 1, 10, 'Attack', 'GrowthFormation' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Mass Raid T1',
    Plan = 'MassRaidRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 1, 10, 'Attack', 'GrowthFormation' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Mass Raid T1 Frigate',
    Plan = 'MassRaidRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.FRIGATE * categories.TECH1, 1, 20, 'Attack', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Intelli Sea Attack T1',
    Plan = 'NavalAttackAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.FRIGATE * categories.TECH1, 1, 20, 'Attack', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Intelli Sea Attack T123',
    Plan = 'NavalAttackAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE - categories.xsb3202, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL - categories.xsb3202, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.DESTROYER, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.CRUISER, 0, 20, 'Artillery', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Attack Ranged T123',
    Plan = 'NavalRangedAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE - categories.xsb3202, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * (categories.DESTROYER + categories.BATTLESHIP), 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * ( categories.CRUISER + categories.xas0306 + categories.NUKE ), 1, 20, 'Artillery', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAIT1SeaSubQueue',
    FactionSquads = {
        UEF = {
            { 'ues0203', 1, 3, 'attack', 'none' },
            { 'ues0103', 1, 1, 'attack', 'none' }
        },
        Aeon = {
            { 'uas0203', 1, 3, 'attack', 'none' },
            { 'uas0102', 1, 1, 'attack', 'none' }
        },
        Cybran = {
            { 'urs0203', 1, 3, 'attack', 'none' },
            { 'urs0103', 1, 1, 'attack', 'none' }
        },
        Seraphim = {
            { 'xss0203', 1, 3, 'attack', 'none' },
            { 'xss0103', 1, 1, 'attack', 'none' }
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAIT2SeaSubQueue',
    FactionSquads = {
        UEF = {
            { 'xes0102', 1, 1, 'attack', 'none' },
            { 'ues0201', 1, 1, 'attack', 'none' }
        },
        Aeon = {
            { 'xas0204', 1, 1, 'attack', 'none' },
            { 'uas0201', 1, 1, 'attack', 'none' }
        },
        Cybran = {
            { 'xrs0204', 1, 1, 'attack', 'none' },
            { 'urs0201', 1, 1, 'attack', 'none' }
        },
        Seraphim = {
            { 'xss0201', 1, 2, 'attack', 'none' },
        },
    }
}

PlatoonTemplate { 
    Name = 'RNGAIT2SeaAttackRangedQueue',
    FactionSquads = {
        UEF = {
            { 'ues0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'ues0202', 1, 2, 'Artillery', 'None' },     -- Sea Cruiser
         },
        Aeon = {
            { 'xas0204', 1, 1, 'Attack', 'none' },       -- Sub Killer
            { 'uas0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
            { 'uas0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            
        },
        Cybran = {
            { 'xrs0204', 1, 1, 'Attack', 'none' },       -- Sub Killer
            { 'urs0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
            { 'urs0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            
        },
        Seraphim = {
            { 'xss0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
            { 'xss0202', 1, 2, 'Artillery', 'None' },     -- Sea Cruiser
        },
    }
}

PlatoonTemplate { 
    Name = 'RNGAIT3SeaAttackRangedQueue',
    FactionSquads = {
        UEF = {
            { 'ues0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'ues0304', 1, 1, 'Artillery', 'None' },     -- Strat Sub
         },
        Aeon = {
            { 'xas0204', 2, 1, 'Attack', 'none' },       -- Sub Killer
            { 'xas0306', 1, 1, 'Artillery', 'none' },       -- Missile Boat
            { 'uas0304', 1, 1, 'Artillery', 'None' },     -- Strat Sub
        },
        Cybran = {
            { 'xrs0204', 2, 1, 'Attack', 'none' },       -- Sub Killer
            { 'urs0304', 1, 1, 'Artillery', 'none' },       -- Strat Sub
        },
        Seraphim = {
            { 'xss0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
        },
    }
}


PlatoonTemplate {
    Name = 'RNGAIT3SeaSubQueue',
    FactionSquads = {
        UEF = {
            { 'ues0203', 1, 1, 'attack', 'none' },
            { 'xes0102', 1, 2, 'attack', 'none' },
            { 'ues0201', 1, 1, 'attack', 'none' },
            { 'ues0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
        },
        Aeon = {
            { 'uas0203', 1, 1, 'attack', 'none' },
            { 'xas0204', 1, 2, 'attack', 'none' },
            { 'uas0201', 1, 1, 'attack', 'none' },
            { 'uas0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
        },
        Cybran = {
            { 'urs0203', 1, 1, 'attack', 'none' },
            { 'xrs0204', 1, 2, 'attack', 'none' },
            { 'urs0201', 1, 1, 'attack', 'none' },
            { 'urs0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
        },
        Seraphim = {
            { 'xss0203', 1, 1, 'attack', 'none' },
            { 'xss0201', 1, 2, 'attack', 'none' },
            { 'xss0201', 1, 1, 'attack', 'none' },
            { 'xss0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
        },
    }
}

PlatoonTemplate { 
    Name = 'RNGAIT3SeaAttackQueue',
    FactionSquads = {
        UEF = {
            { 'ues0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'ues0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xes0102', 1, 1, 'Attack', 'none' },       -- Sub Killer
            { 'ues0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
            { 'ues0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
         },
        Aeon = {
            { 'uas0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'uas0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xas0204', 1, 1, 'Attack', 'none' },       -- Sub Killer
            { 'uas0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
            { 'uas0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
            { 'xas0306', 1, 1, 'attack', 'None' },       -- Missile Boat
        },
        Cybran = {
            { 'urs0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'urs0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xrs0204', 1, 1, 'Attack', 'none' },       -- Sub Killer
            { 'urs0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
            { 'urs0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
        },
        Seraphim = {
            { 'xss0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'xss0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xss0304', 1, 1, 'attack', 'None' },        -- Sub Killer
            { 'xss0302', 1, 1, 'Artillery', 'None' },     -- BattleShip
            { 'xss0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
        },
    }
}