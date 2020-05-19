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
    Name = 'RNGAI Sea Attack T1',
    Plan = 'NavalForceAI',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1, 1, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.FRIGATE * categories.TECH1, 1, 20, 'Attack', 'GrowthFormation' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Sea Attack T123',
    Plan = 'NavalForceAI',
    GlobalSquads = {
        { categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL, 0, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.DESTROYER, 1, 20, 'Attack', 'GrowthFormation' },
        { categories.MOBILE * categories.NAVAL * categories.CRUISER, 0, 20, 'Artillery', 'GrowthFormation' },
    },
}

PlatoonTemplate { 
    Name = 'RNGAIT2SeaAttackQueue',
    FactionSquads = {
        UEF = {
            { 'ues0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'ues0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xes0102', 2, 1, 'Attack', 'none' },       -- Torp Boat
            { 'ues0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
         },
        Aeon = {
            { 'uas0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'uas0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xas0204', 2, 1, 'Attack', 'none' },       -- Sub Killer
            { 'uas0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
        },
        Cybran = {
            { 'urs0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'urs0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xrs0204', 2, 1, 'Attack', 'none' },       -- Sub Killer
            { 'urs0201', 1, 1, 'Attack', 'none' },       -- Sea Destroyer
        },
        Seraphim = {
            { 'xss0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
            { 'xss0202', 1, 1, 'Artillery', 'None' },     -- Sea Cruiser
            { 'xss0201', 1, 2, 'Attack', 'none' },       -- Sea Destroyer
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