--[[
    File    :   /lua/AI/PlatoonTemplates/MicroAITemplates.lua
    Author  :   SoftNoob
    Summary :
        Responsible for defining a mapping from AIBuilders keys -> Plans (Plans === platoon.lua functions)
]]

PlatoonTemplate {
    Name = 'RNGAI T1LandScoutForm',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.LAND * categories.SCOUT * categories.TECH1, 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1EngineerReclaimer',
    Plan = 'ReclaimAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH1, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI T1 Guard Marker Small',
    Plan = 'GuardMarkerRNG',    
    GlobalSquads = {
        { categories.TECH1 * categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 3, 10, 'attack', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1 Mass Raiders Small',
    Plan = 'MassRaidRNG',    
    GlobalSquads = {
        { categories.TECH1 * categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 3, 8, 'attack', 'none' },
        { categories.TECH1 * categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 5, 'artillery', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1 Mass Raiders Medium',
    Plan = 'MassRaidRNG',    
    GlobalSquads = {
        { categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 4, 15, 'attack', 'none' },
        { categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 1, 5, 'artillery', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1 Guard Marker Medium',
    Plan = 'GuardMarkerRNG',    
    GlobalSquads = {
        { categories.TECH1 * categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.INDIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 5, 30, 'attack', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1 Mass Hunters Transport',
    Plan = 'GuardMarkerRNG',    
    GlobalSquads = {
        { categories.TECH1 * categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.INDIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 3, 5, 'attack', 'none' },
        { categories.LAND * categories.ENGINEER - categories.COMMAND, 1, 1, 'support', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Small',
    Plan = 'StrikeForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          3, -- Min number of units.
          8, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Small Ranged',
    Plan = 'StrikeForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          3, -- Min number of units.
          8, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.MOBILE * categories.LAND - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          2, -- Min number of units.
          5, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Medium',
    Plan = 'AttackForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND - categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT,-- Type of units.
          4, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT,-- Type of units.
          1, -- Min number of units.
          3, -- Max number of units.
          'support', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Large',
    Plan = 'AttackForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND - categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT, -- Type of units.
          8, -- Min number of units.
          14, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'GrowthFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
          { categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT, -- Type of units.
          2, -- Min number of units.
          4, -- Max number of units.
          'support', -- platoon types: 'support', 'attack', 'scout',
          'GrowthFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Large T2',
    Plan = 'AttackForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.TECH2 - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT, -- Type of units.
          6, -- Min number of units.
          14, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'GrowthFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.SCOUT, 0, 1, 'scout', 'none' },
    },
}

PlatoonTemplate { Name = 'RNGAIT1LandAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 4, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
			{ 'uel0103', 1, 2, 'Artillery', 'none' },	-- artillery
            { 'uel0104', 1, 1, 'Guard', 'none' },		-- AA
         },
        Aeon = {
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 4, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
			{ 'ual0103', 1, 2, 'Artillery', 'none' },	-- artillery
            { 'ual0104', 1, 1, 'Guard', 'none' },		-- AA
        },
        Cybran = {
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 4, 'Attack', 'none' },		-- Mantis
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
			{ 'url0103', 1, 2, 'Artillery', 'none' },	-- arty
            { 'url0104', 1, 1, 'Guard', 'none' },		-- AA
        },
        Seraphim = {
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 4, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
			{ 'xsl0103', 1, 2, 'Artillery', 'none' },	-- artillery
            { 'xsl0104', 1, 1, 'Guard', 'none' },		-- AA
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT2LandAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uel0202', 2, 6, 'Attack', 'none' },       -- Heavy Tank
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'del0204', 1, 3, 'Attack', 'none' },      -- Gatling Bot
            { 'uel0111', 1, 3, 'Artillery', 'none' },   -- MML
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'uel0307', 1, 1, 'Guard', 'none' },       -- Mobile Shield
         },
        Aeon = {
            { 'ual0202', 2, 6, 'Attack', 'none' },      -- Heavy Tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0111', 1, 3, 'Artillery', 'none' },   -- MML
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'ual0307', 1, 1, 'Guard', 'none' },       -- Mobile Shield
        },
        Cybran = {
            { 'url0202', 2, 6, 'Attack', 'none' },      -- Heavy Tank
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'drl0204', 1, 3, 'Attack', 'none' },      -- Rocket Bot
            { 'url0111', 1, 3, 'Artillery', 'none' },   -- MML
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0205', 1, 1, 'Guard', 'none' },       -- AA
            { 'url0306', 1, 1, 'Guard', 'none' },       -- Mobile Stealth
        },
        Seraphim = {
            { 'xsl0202', 2, 7, 'Attack', 'none' },      -- Assault Bot
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0111', 1, 3, 'Artillery', 'none' },   -- MML
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0205', 1, 1, 'Guard', 'none' },       -- AA
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT3LandAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uel0303', 2, 6, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xel0305', 1, 3, 'Attack', 'none' },      -- Armored Assault Bot
            { 'uel0304', 1, 2, 'Artillery', 'none' },   -- artillery
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xel0306', 1, 2, 'Artillery', 'none' },   -- artillery
            { 'delk002', 1, 1, 'Guard', 'none' },       -- AA
         },
        Aeon = {
            { 'ual0303', 2, 6, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xal0305', 1, 2, 'Attack', 'none' },      -- Sniper Bot
            { 'ual0304', 1, 2, 'Artillery', 'none' },   -- artillery
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'dal0310', 1, 1, 'Artillery', 'none' },   -- artillery
            { 'dalk003', 1, 1, 'Guard', 'none' },       -- AA
        },
        Cybran = {
            { 'url0303', 1, 6, 'Attack', 'none' },      -- Siege Assault Bot
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xrl0305', 2, 3, 'Attack', 'none' },      -- Armored Assault Bot
            { 'url0304', 1, 2, 'Artillery', 'none' },   -- artillery
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'drlk001', 1, 1, 'Guard', 'none' },       -- AA
        },
        Seraphim = {
            { 'xsl0303', 2, 6, 'Attack', 'none' },       -- Siege Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0305', 1, 2, 'Attack', 'none' },       -- Sniper Bot
            { 'xsl0304', 1, 2, 'Artillery', 'none' },   -- artillery
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0307', 0, 1, 'Guard', 'none' },       -- Mobile Shield
            { 'dslk004', 1, 1, 'Guard', 'none' },       -- AA
        },
    }
}