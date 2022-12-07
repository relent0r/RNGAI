--[[
    File    :   /lua/AI/PlatoonTemplates/MicroAITemplates.lua
    Author  :   SoftNoob
    Summary :
        Responsible for defining a mapping from AIBuilders keys -> Plans (Plans === platoon.lua functions)
]]

local landDirectFireCategory = categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER - categories.xrl0302
local landDirectFireCategoryNoSniper = categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.SNIPER - categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL - categories.xrl0302
local landIndirectFireCategory = categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER

PlatoonTemplate {
    Name = 'InitialBuildQueueRNG',
    FactionSquads = {
        UEF = {
            { 'uel0105', 1, 1, 'support', 'None' }
        },
        Aeon = {
            { 'ual0105', 1, 1, 'support', 'None' }
        },
        Cybran = {
            { 'url0105', 1, 1, 'support', 'None' }
        },
        Seraphim = {
            { 'xsl0105', 1, 1, 'support', 'None' }
        },
    }
}

PlatoonTemplate {
    Name = 'RNGAI LandFeeder',
    Plan = 'FeederPlatoon',
    GlobalSquads = {
        { categories.LAND * categories.MOBILE - categories.SNIPER - categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL - categories.xrl0302, 1, 100, 'Attack', 'none' },
    }
}

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
        { categories.ENGINEER * categories.TECH1 - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI T2EngineerReclaimer',
    Plan = 'ReclaimAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH2, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI T3EngineerReclaimer',
    Plan = 'ReclaimAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * categories.TECH3 - categories.SUBCOMMANDER, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI T12EngineerReclaimer',
    Plan = 'ReclaimAIRNG',
    GlobalSquads = {
        { categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, 1, 1, 'support', 'None' }
    },
}

PlatoonTemplate {
    Name = 'RNGAI Guard Marker Small',
    Plan = 'GuardMarkerRNG',    
    GlobalSquads = {
        { landDirectFireCategoryNoSniper, 4, 10, 'Attack', 'none' },
        { categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 1, 10, 'Artillery', 'none' },
        { categories.LAND * categories.MOBILE * categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'Attack', 'none' },
        { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'Attack', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'Attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI MobileBombAttack',
    Plan = 'PlatoonMergeRNG',
    GlobalSquads = {
        { categories.xrl0302 , 2, 10, 'Attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1 Mass Raiders Mini',
    Plan = 'MassRaidRNG',    
    GlobalSquads = {
        { categories.TECH1 * categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL - categories.xrl0302, 1, 2, 'Attack', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'Guard', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1 Zone Raiders Small',
    Plan = 'ZoneControlRNG',    
    GlobalSquads = {
        { landDirectFireCategoryNoSniper, 3, 8, 'Attack', 'none' },
        { categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.TECH3 - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL - categories.SILO, 0, 1, 'Artillery', 'none' },
        { categories.LAND * categories.MOBILE * categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 1, 'guard', 'none' },
        { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'Attack', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'Guard', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI Zone Raiders Medium',
    Plan = 'ZoneControlRNG',    
    GlobalSquads = {
        { categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL - categories.TECH3 - categories.xrl0302 , 4, 15, 'attack', 'none' },
        { categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.TECH3 - categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL - categories.xrl0302  , 0, 4, 'attack', 'none' },
        { categories.LAND * categories.MOBILE * categories.INDIRECTFIRE - categories.TECH3 - categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL - categories.SILO, 0, 5, 'Artillery', 'none' },
        { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
        { categories.LAND * categories.MOBILE * categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'Guard', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI Antiair Small',
    Plan = 'GunshipStrikeAIRNG',    
    GlobalSquads = {
        { categories.LAND * categories.MOBILE * categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 1, 10, 'attack', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'guard', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Spam Intelli',
    Plan = 'HuntAIPATHRNG', -- The platoon function to use.
    GlobalSquads = {
        { landDirectFireCategory, 4, 15, 'attack', 'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
        { categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          0, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.MOBILE * (categories.SHIELD + categories.STEALTHFIELD) - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL, 0, 3, 'guard', 'none' },
          { categories.LAND * categories.SCOUT - categories.EXPERIMENTAL, 0, 1, 'guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Spam Intelli Hover',
    Plan = 'HuntAIPATHRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.HOVER * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          4, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Spam Intelli Amphib',
    Plan = 'HuntAIPATHRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * (categories.AMPHIBIOUS + categories.HOVER) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          4, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Spam',
    Plan = 'ZoneControlRNG', -- The platoon function to use.
    GlobalSquads = {
        { landDirectFireCategory, 4, 18, 'attack', 'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
        { categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          0, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.SCOUT, 0, 1, 'guard', 'none' },
          { categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI Zone Control',
    Plan = 'ZoneControlRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER - categories.SILO - categories.SHIELD - categories.xrl0302, -- Type of units.
          3, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.SCOUT, 0, 1, 'guard', 'none' },
          { categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Spam Aeon Intelli',
    Plan = 'HuntAIPATHRNG', -- The platoon function to use.
    GlobalSquads = {
        { landDirectFireCategory, 4, 12, 'Attack', 'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
        { categories.MOBILE * categories.LAND * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.INDIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          0, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.SCOUT, 1, 2, 'guard', 'none' },
          { categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL, 0, 2, 'Guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Small Ranged',
    Plan = 'HuntAIPATHRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          3, -- Min number of units.
          8, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.MOBILE * categories.ANTIAIR - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 1, 'guard', 'none' },
          { categories.LAND * categories.SCOUT, 0, 1, 'guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Medium',
    Plan = 'AttackForceAIRNG', -- The platoon function to use.
    GlobalSquads = {
        { landDirectFireCategory,-- Type of units.
          4, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT,-- Type of units.
          1, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' },
          { categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT,-- Type of units.
          1, -- Min number of units.
          3, -- Max number of units.
          'guard', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.SCOUT, 0, 1, 'guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Large',
    Plan = 'AttackForceAIRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT - categories.xrl0302, -- Type of units.
          8, -- Min number of units.
          14, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'GrowthFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL - categories.ENGINEER - categories.SCOUT, -- Type of units.
          2, -- Min number of units.
          4, -- Max number of units.
          'support', -- platoon types: 'support', 'attack', 'scout',
          'GrowthFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * categories.SHIELD - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.SCOUT, 0, 1, 'guard', 'none' },
    },
}

-- TruePlatoon Template
PlatoonTemplate {
    Name = 'RNG TruePlatoon Combat',
    Plan = 'TruePlatoonRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.DIRECTFIRE * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER - (categories.SNIPER + categories.xel0305 + categories.xal0305 + categories.xrl0305 + categories.xsl0305 + categories.drl0204 + categories.del0204) - categories.xrl0302, -- Type of units.
          2, -- Min number of units.
          25, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER - categories.uel0304 - categories.url0304 - categories.xsl0304, -- Type of units.
          0, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
          { categories.LAND * categories.MOBILE * (categories.SHIELD + categories.STEALTHFIELD) - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 0, 2, 'guard', 'none' },
          { categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL, 0, 3, 'guard', 'none' },
          { categories.LAND * categories.SCOUT - categories.EXPERIMENTAL, 0, 1, 'guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'T4ExperimentalLandRNG',
    Plan = 'ExperimentalAIHubRNG',
    GlobalSquads = {
        { categories.EXPERIMENTAL * categories.LAND * categories.MOBILE - categories.INSIGNIFICANTUNIT, 1, 1, 'attack', 'none' }
    },
}

PlatoonTemplate {
    Name = 'RNGAIT1LandScoutBurst',
    FactionSquads = {
        UEF = {
            { 'uel0101', 1, 2, 'scout', 'None' },
        },
        Aeon = {
            { 'ual0101', 1, 2, 'scout', 'None' },
        },
        Cybran = {
            { 'url0101', 1, 2, 'scout', 'None' },
        },
        Seraphim = {
            { 'xsl0101', 1, 2, 'scout', 'None' },
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT2AttackBot',
    FactionSquads = {
        UEF = {
            { 'del0204', 1, 1, 'Attack', 'none' },      -- Gatling Bot
        },
        Cybran = {
            { 'drl0204', 1, 1, 'Attack', 'none' },      -- Rocket Bot
        },
        Seraphim = {
            { 'xsl0202', 1, 1, 'attack', 'none' },      -- Ilshavoh , its here because of the naming convention in the ratios
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT2MobileStealth',
    FactionSquads = {
        Cybran = {
            { 'url0306', 1, 1, 'Attack', 'none' },      -- Rocket Bot
        },
    }
}


PlatoonTemplate { Name = 'RNGAIT1InitialAttackBuild20k',
    FactionSquads = {
        UEF = {
            { 'uel0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'uel0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'uel0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'uel0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'uel0101', 1, 5, 'Scout', 'none' },		-- Land Scout
            { 'uel0105', 1, 3, 'support', 'None' },     -- Engineer
         },
        Aeon = {
            { 'ual0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'ual0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'ual0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'ual0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'ual0101', 1, 5, 'Scout', 'none' },		-- Land Scout
            { 'ual0105', 1, 3, 'support', 'None' },     -- Engineer
        },
        Cybran = {
            { 'url0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'url0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
            { 'url0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'url0101', 1, 5, 'Scout', 'none' },		-- Land Scout
            { 'url0105', 1, 3, 'support', 'None' },     -- Engineer
        },
        Seraphim = {
            { 'xsl0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xsl0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'xsl0101', 1, 5, 'Scout', 'none' },		-- Land Scout
            { 'xsl0105', 1, 3, 'support', 'None' },     -- Engineer
        },
        Nomads = {
            { 'xnl0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'xnl0106', 1, 2, 'Attack', 'none' },		-- Grass Hopper
            { 'xnl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xnl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xnl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xnl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xnl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xnl0107', 1, 2, 'Attack', 'none' },		-- Tank Destroyer
            { 'xnl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xnl0101', 1, 5, 'Scout', 'none' },		-- Land Scout
            { 'xnl0103', 1, 2, 'Guard', 'none' },		-- AA
            { 'xnl0105', 1, 3, 'support', 'None' },     -- Engineer
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT1InitialAttackBuild10k',
    FactionSquads = {
        UEF = {
            { 'uel0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'uel0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 1, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0201', 1, 1, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'uel0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'uel0101', 1, 5, 'Scout', 'none' },		-- Land Scout
         },
        Aeon = {
            { 'ual0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'ual0106', 1, 1, 'attack', 'None' },       -- Labs
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0106', 1, 1, 'attack', 'None' },       -- Labs
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 1, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 1, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'ual0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'ual0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
        Cybran = {
            { 'url0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'url0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 1, 'Attack', 'none' },		-- Mantis
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
            { 'url0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 1, 'Attack', 'none' },		-- Mantis
            { 'url0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'url0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
            { 'url0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'url0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
        Seraphim = {
            { 'xsl0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'xsl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'xsl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0104', 1, 2, 'Guard', 'none' },		-- AA
            { 'xsl0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
        Nomads = {
            { 'xnl0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'xnl0106', 1, 2, 'Attack', 'none' },		-- Grass Hopper
            { 'xnl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xnl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
            { 'xnl0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'xnl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xnl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xnl0103', 1, 2, 'Guard', 'none' },		-- AA
            { 'xnl0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT1InitialAttackBuild5k',
    FactionSquads = {
        UEF = {
            { 'uel0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'uel0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 1, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'uel0101', 1, 3, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 4, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'uel0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'uel0201', 1, 4, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'uel0101', 1, 5, 'Scout', 'none' },		-- Land Scout

         },
        Aeon = {
            { 'ual0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'ual0106', 1, 1, 'attack', 'None' },       -- Labs
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0106', 1, 1, 'attack', 'None' },       -- Labs
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 1, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'ual0201', 1, 3, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'ual0101', 1, 3, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 4, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'ual0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'ual0201', 1, 4, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'ual0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
        Cybran = {
            { 'url0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'url0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0106', 1, 1, 'attack', 'None' },      -- Labs
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 1, 'Attack', 'none' },		-- Mantis
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'url0107', 1, 3, 'Attack', 'none' },		-- Mantis
            { 'url0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'url0101', 1, 3, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 4, 'Attack', 'none' },		-- Mantis
            { 'url0103', 1, 2, 'Artillery', 'none' },	-- arty
            { 'url0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'url0107', 1, 4, 'Attack', 'none' },		-- Mantis
            { 'url0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'url0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
        Seraphim = {
            { 'xsl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 3, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0105', 1, 2, 'support', 'None' },     -- Engineer
            { 'xsl0101', 1, 3, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 4, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'xsl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xsl0201', 1, 4, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'xsl0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
        Nomads = {
            { 'xnl0105', 1, 3, 'support', 'None' },     -- Engineer
            { 'xnl0106', 1, 2, 'Attack', 'none' },		-- Grass Hopper
            { 'xnl0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'xnl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
            { 'xnl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xnl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xnl0201', 1, 3, 'Attack', 'none' },		-- Medium Tank
            { 'xnl0101', 1, 3, 'Scout', 'none' },		-- Land Scout
            { 'xnl0107', 1, 2, 'Attack', 'none' },		-- Tank Destroyer
            { 'xnl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xnl0103', 1, 2, 'Guard', 'none' },		-- AA
            { 'xnl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xnl0101', 1, 2, 'Scout', 'none' },		-- Land Scout
            { 'xnl0105', 1, 1, 'support', 'None' },     -- Engineer
            { 'xnl0101', 1, 5, 'Scout', 'none' },		-- Land Scout
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT1LandAttackQueueExp',
    FactionSquads = {
        UEF = {
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0201', 1, 2, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'uel0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'uel0201', 1, 1, 'Attack', 'none' },		-- Striker Medium Tank
         },
        Aeon = {
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 2, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'ual0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0201', 1, 1, 'Attack', 'none' },		-- Light Hover tank
        },
        Cybran = {
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0107', 1, 2, 'Attack', 'none' },		-- Mantis
            { 'url0103', 1, 2, 'Artillery', 'none' },	-- arty
            { 'url0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'url0107', 1, 1, 'Attack', 'none' },		-- Mantis
        },
        Seraphim = {
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0201', 1, 2, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0103', 1, 2, 'Artillery', 'none' },	-- Artillery
            { 'xsl0104', 1, 1, 'Guard', 'none' },		-- AA
            { 'xsl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT2AmphibAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uel0203', 1, 1, 'Attack', 'none' },       -- Amphib Tank
         },
        Aeon = {
            { 'xal0203', 1, 1, 'Attack', 'none' },      -- Amphib Tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
        },
        Cybran = {
            { 'url0203', 1, 1, 'Attack', 'none' },      -- Amphib Tank
        },
        Seraphim = {
            { 'xsl0203', 1, 1, 'Attack', 'none' },      -- Amphib Tank
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT2AmphibAttackQueueSiege',
    FactionSquads = {
        UEF = {
            { 'uel0203', 2, 3, 'Attack', 'none' },       -- Amphib Tank
            { 'uel0111', 1, 1, 'Artillery', 'none' },   -- MML
         },
        Aeon = {
            { 'xal0203', 2, 3, 'Attack', 'none' },      -- Amphib Tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0111', 1, 1, 'Artillery', 'none' },   -- MML
        },
        Cybran = {
            { 'url0203', 2, 3, 'Attack', 'none' },      -- Amphib Tank
            { 'url0111', 1, 1, 'Artillery', 'none' },   -- MML
        },
        Seraphim = {
            { 'xsl0203', 2, 3, 'Attack', 'none' },      -- Amphib Tank
            { 'xsl0111', 1, 1, 'Artillery', 'none' },   -- MML
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT2LandAttackQueue',
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

PlatoonTemplate { Name = 'RNGAIT2LandAttackQueueExp',
    FactionSquads = {
        UEF = {
            { 'uel0202', 2, 2, 'Attack', 'none' },       -- Heavy Tank
            { 'del0204', 2, 1, 'Attack', 'none' },      -- Gatling Bot
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
         },
        Aeon = {
            { 'ual0202', 2, 3, 'Attack', 'none' },      -- Heavy Tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            
        },
        Cybran = {
            { 'url0202', 2, 2, 'Attack', 'none' },      -- Heavy Tank
            { 'drl0204', 2, 1, 'Attack', 'none' },      -- Rocket Bot
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
        },
        Seraphim = {
            { 'xsl0202', 2, 3, 'Attack', 'none' },      -- Assault Bot
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT1LandResponse',
    FactionSquads = {
        UEF = {
            { 'uel0201', 1, 1, 'Attack', 'none' },		-- Striker Medium Tank
            { 'uel0103', 1, 1, 'Artillery', 'none' },	-- Artillery
        },
        Aeon = {
            { 'ual0201', 1, 1, 'Attack', 'none' },		-- Light Hover tank
            { 'ual0103', 1, 1, 'Artillery', 'none' },	-- Artillery
        },
        Cybran = {
            { 'url0107', 1, 1, 'Attack', 'none' },		-- Mantis
            { 'url0103', 1, 1, 'Artillery', 'none' },	-- arty
        },
        Seraphim = {
            { 'xsl0201', 1, 1, 'Attack', 'none' },		-- Medium Tank
            { 'xsl0103', 1, 1, 'Artillery', 'none' },	-- Artillery
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT3LandResponse',
    FactionSquads = {
        UEF = {
            { 'uel0303', 1, 1, 'Attack', 'none' },      -- Heavy Assault Bot
        },
        Aeon = {
            { 'ual0303', 1, 1, 'Attack', 'none' },      -- Heavy Assault Bot
        },
        Cybran = {
            { 'url0303', 1, 1, 'Attack', 'none' },      -- Siege Assault Bot
        },
        Seraphim = {
            { 'xsl0303', 1, 1, 'Attack', 'none' },       -- Siege Tank
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT3AmphibAttackQueue',
    FactionSquads = {
        UEF = {
            { 'xel0305', 1, 1, 'Attack', 'none' },       -- Armoured Assault Bot
         },
        Aeon = {
            { 'xal0203', 1, 1, 'Attack', 'none' },      -- Amphib Tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
        },
        Cybran = {
            { 'xrl0305', 1, 1, 'Attack', 'none' },      -- Armoured Assault Bot
        },
        Seraphim = {
            { 'xsl0303', 1, 1, 'Attack', 'none' },      -- Heavy Tank
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT3AmphibAttackQueueSiege',
    FactionSquads = {
        UEF = {
            { 'xel0305', 1, 3, 'Attack', 'none' },       -- Armoured Assault Bot
            { 'uel0304', 1, 1, 'Artillery', 'none' },   -- Artillery
         },
        Aeon = {
            { 'xal0203', 1, 3, 'Attack', 'none' },      -- Amphib Tank
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0304', 1, 1, 'Artillery', 'none' },   -- Artillery
        },
        Cybran = {
            { 'xrl0305', 1, 3, 'Attack', 'none' },      -- Armoured Assault Bot
            { 'url0304', 1, 1, 'Artillery', 'none' },   -- Artillery
        },
        Seraphim = {
            { 'xsl0303', 1, 3, 'Attack', 'none' },      -- Heavy Tank
            { 'xsl0304', 1, 1, 'Artillery', 'none' },   -- Artillery
        },
    }
}

PlatoonTemplate { Name = 'RNGAIT3LandAttackQueue',
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

PlatoonTemplate { Name = 'RNGAIT3LandAttackQueueHeavy',
    FactionSquads = {
        UEF = {
            { 'xel0305', 1, 2, 'Attack', 'none' },      -- Armored Assault Bot
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'delk002', 1, 1, 'Guard', 'none' },       -- AA
            { 'uel0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'uel0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'uel0303', 2, 2, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'xel0305', 1, 4, 'Attack', 'none' },      -- Armored Assault Bot
            { 'uel0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'uel0304', 1, 3, 'Artillery', 'none' },   -- Artillery
            { 'xel0306', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'delk002', 1, 1, 'Guard', 'none' },       -- AA
         },
        Aeon = {
            { 'ual0303', 2, 3, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'dalk003', 1, 1, 'Guard', 'none' },       -- AA
            { 'ual0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'ual0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'ual0303', 2, 4, 'Attack', 'none' },      -- Heavy Assault Bot
            { 'xal0305', 1, 2, 'Attack', 'none' },      -- Sniper Bot
            { 'ual0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'ual0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'dal0310', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'dalk003', 1, 1, 'Guard', 'none' },       -- AA
        },
        Cybran = {
            { 'xrl0305', 2, 2, 'Attack', 'none' },      -- Armored Assault Bot
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'drlk001', 1, 1, 'Guard', 'none' },       -- AA
            { 'url0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'url0304', 1, 1, 'Artillery', 'none' },   -- Artillery
            { 'url0303', 1, 2, 'Attack', 'none' },      -- Siege Assault Bot
            { 'xrl0305', 2, 4, 'Attack', 'none' },      -- Armored Assault Bot
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'url0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'url0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'drlk001', 1, 1, 'Guard', 'none' },       -- AA
        },
        Seraphim = {
            { 'xsl0303', 2, 4, 'Attack', 'none' },       -- Siege Tank
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'dslk004', 1, 1, 'Guard', 'none' },       -- AA
            { 'xsl0309', 1, 1, 'support', 'None' },     -- T3 Engineer
            { 'xsl0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'xsl0303', 2, 3, 'Attack', 'none' },       -- Siege Tank
            { 'xsl0305', 1, 2, 'Attack', 'none' },       -- Sniper Bot
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0304', 1, 2, 'Artillery', 'none' },   -- Artillery
            { 'xsl0101', 1, 1, 'Scout', 'none' },		-- Land Scout
            { 'xsl0307', 0, 1, 'Guard', 'none' },       -- Mobile Shield
            { 'dslk004', 1, 1, 'Guard', 'none' },       -- AA
        },
    }
}