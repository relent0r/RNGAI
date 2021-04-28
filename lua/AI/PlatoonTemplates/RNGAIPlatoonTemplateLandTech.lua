--[[
    File    :   /lua/AI/PlatoonTemplates/MicroAITemplates.lua
    Author  :   SoftNoob
    Summary :
        Responsible for defining a mapping from AIBuilders keys -> Plans (Plans === platoon.lua functions)
]]


PlatoonTemplate {
    Name = 'RNGTECH Hero',
    Plan = 'HuntAIRNGHero', -- The platoon function to use.
    GlobalSquads = {
        { categories.xel0305 + categories.xal0305 + categories.xrl0305 + categories.xsl0305 + categories.ual0303 + categories.uel0303 + categories.url0303 + categories.xsl0303, -- Type of units.
          1, -- Min number of units.
          1, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}
PlatoonTemplate {
    Name = 'RNGTECH Early Hero T1',
    Plan = 'HuntAIRNGHero', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * (categories.TECH1) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER - categories.SILO, -- Type of units.
          1, -- Min number of units.
          1, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}
PlatoonTemplate {
    Name = 'RNGTECH Early Hero T2',
    Plan = 'HuntAIRNGHero', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * (categories.TECH2) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER - categories.SILO, -- Type of units.
          1, -- Min number of units.
          1, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}
PlatoonTemplate { Name = 'RNGTECHEarlyExpandEngineers',
    FactionSquads = {
        UEF = {
            { 'uel0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'uel0201', 1, 1, 'Attack', 'none' },		-- Striker Medium Tank
         },
        Aeon = {
            { 'ual0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'ual0201', 1, 1, 'Attack', 'none' },		-- Light Hover tank
        },
        Cybran = {
            { 'url0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'url0107', 1, 1, 'Attack', 'none' },		-- Mantis
        },
        Seraphim = {
            { 'xsl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
        },
    }
}

PlatoonTemplate { Name = 'RNGTECHT1InitialAttackBuild10k',
    FactionSquads = {
        UEF = {
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            --{ 'uel0106', 1, 2, 'attack', 'None' },      -- Labs
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0201', 1, 4, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'uel0201', 1, 3, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
         },
        Aeon = {
            { 'ual0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            --{ 'ual0106', 1, 2, 'attack', 'None' },       -- Labs
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0201', 1, 4, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'ual0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'ual0201', 1, 3, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
        },
        Cybran = {
            { 'url0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            --{ 'url0106', 1, 2, 'attack', 'None' },      -- Labs
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
            { 'url0107', 1, 4, 'Attack', 'none' },		-- Mantis
            { 'url0103', 1, 1, 'Artillery', 'none' },	-- arty
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
            { 'url0103', 1, 1, 'Artillery', 'none' },	-- arty
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'url0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'url0107', 1, 3, 'Attack', 'none' },		-- Mantis
            { 'url0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
        },
        Seraphim = {
            { 'xsl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 3, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'xsl0201', 1, 4, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 3, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'xsl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
        },
    }
}

PlatoonTemplate { Name = 'RNGTECHT1LandAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 4, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'uel0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'uel0201', 1, 3, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'uel0201', 1, 3, 'Attack', 'none' },		-- Striker Medium Tank
         },
        Aeon = {
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 4, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'ual0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'ual0201', 1, 3, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'ual0201', 1, 3, 'Attack', 'none' },		-- Light Hover tank
        },
        Cybran = {
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 4, 'Attack', 'none' },		-- Mantis
            { 'url0103', 1, 1, 'Artillery', 'none' },	-- arty
            { 'url0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'url0107', 1, 3, 'Attack', 'none' },		-- Mantis
            { 'url0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'url0103', 1, 2, 'Artillery', 'none' },	-- arty
            { 'url0107', 1, 3, 'Attack', 'none' },		-- Mantis
        },
        Seraphim = {
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 4, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'xsl0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'xsl0201', 1, 3, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xsl0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'xsl0201', 1, 3, 'Attack', 'none' },		-- Medium Tank
        },
    }
}

PlatoonTemplate { Name = 'RNGTECHT2LandAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uel0202', 2, 3, 'Attack', 'none' },       -- Heavy Tank
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'del0204', 2, 2, 'Attack', 'none' },      -- Gatling Bot
            { 'uel0202', 2, 2, 'Attack', 'none' },       -- Heavy Tank
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'uel0111', 1, 2, 'Artillery', 'none' },   -- MML
            { 'del0204', 2, 2, 'Attack', 'none' },      -- Gatling Bot
            { 'uel0208', 1, 1, 'support', 'None' },      -- T2 Engineer
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'uel0307', 1, 1, 'Guard', 'none' },       -- Mobile Shield
            
         },
        Aeon = {
            { 'ual0202', 2, 4, 'Attack', 'none' },      -- Heavy Tank
            { 'ual0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'ual0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'ual0202', 2, 2, 'Attack', 'none' },      -- Heavy Tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'ual0111', 1, 2, 'Artillery', 'none' },   -- MML
            { 'ual0208', 1, 1, 'support', 'None' },      -- T2 Engineer
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'ual0307', 1, 1, 'Guard', 'none' },       -- Mobile Shield
            
        },
        Cybran = {
            { 'url0202', 2, 3, 'Attack', 'none' },      -- Heavy Tank
            { 'url0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'url0103', 1, 2, 'Artillery', 'none' },	-- arty
            { 'drl0204', 2, 2, 'Attack', 'none' },      -- Rocket Bot
            { 'url0202', 2, 2, 'Attack', 'none' },      -- Heavy Tank
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'url0111', 1, 2, 'Artillery', 'none' },   -- MML
            { 'drl0204', 2, 2, 'Attack', 'none' },      -- Rocket Bot
            { 'url0208', 1, 1, 'support', 'None' },     -- T2 Engineer
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'url0306', 1, 1, 'Guard', 'none' },       -- Mobile Stealth
        },
        Seraphim = {
            { 'xsl0202', 2, 4, 'Attack', 'none' },      -- Assault Bot
            { 'xsl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xsl0103', 1, 1, 'Artillery', 'none' },	-- Artillery
            { 'xsl0202', 2, 3, 'Attack', 'none' },      -- Assault Bot
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'xsl0111', 1, 2, 'Artillery', 'none' },   -- MML
            { 'xsl0208', 1, 1, 'support', 'None' },     -- T2 Engineer
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0205', 1, 1, 'Guard', 'none' },       -- AA
        },
    }
}

PlatoonTemplate { Name = 'RNGTECHT3LandAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uel0303', 1, 3, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'xel0305', 1, 1, 'Attack', 'none' },      -- Armored Assault Bot
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'delk002', 1, 1, 'Guard', 'none' },       -- AA
            { 'uel0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'uel0304', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'xel0305', 1, 3, 'Attack', 'none' },      -- Armored Assault Bot
            { 'uel0303', 1, 2, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'xel0305', 1, 1, 'Attack', 'none' },      -- Armored Assault Bot
            { 'xel0306', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'delk002', 1, 1, 'Guard', 'none' },       -- AA
         },
        Aeon = {
            { 'ual0303', 1, 4, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'dalk003', 1, 1, 'Guard', 'none' },       -- AA
            { 'ual0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'ual0304', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'ual0303', 1, 2, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'xal0305', 1, 2, 'Attack', 'none' },      -- Sniper Bot
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'ual0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            --{ 'dal0310', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'dalk003', 1, 1, 'Guard', 'none' },       -- AA
        },
        Cybran = {
            { 'url0303', 1, 3, 'Attack', 'none' },      -- Siege Assault Bot
            { 'xrl0305', 1, 1, 'Attack', 'none' },      -- Armored Assault Bot
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'drlk001', 1, 1, 'Guard', 'none' },       -- AA
            { 'url0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'url0304', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'xrl0305', 1, 3, 'Attack', 'none' },      -- Armored Assault Bot
            { 'url0303', 1, 2, 'Attack', 'none' },      -- Siege Assault Bot
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'url0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'xrl0305', 1, 2, 'Attack', 'none' },      -- Armored Assault Bot
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'drlk001', 1, 1, 'Guard', 'none' },       -- AA
        },
        Seraphim = {
            { 'xsl0303', 1, 4, 'Attack', 'none' },       -- Siege Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'dslk004', 1, 1, 'Guard', 'none' },       -- AA
            { 'xsl0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'xsl0304', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'xsl0303', 1, 2, 'Attack', 'none' },       -- Siege Tank
            { 'xsl0305', 1, 2, 'Attack', 'none' },       -- Sniper Bot
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xsl0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0307', 1, 1, 'Guard', 'none' },       -- Mobile Shield
            { 'dslk004', 1, 1, 'Guard', 'none' },       -- AA
        },
    }
}
