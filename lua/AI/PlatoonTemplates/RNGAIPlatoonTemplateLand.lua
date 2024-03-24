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
    Name = 'RNGAILandScoutStateMachine',
    Plan = 'StateMachineAIRNG',
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
    Name = 'LandCombatStateMachineRNG',
    Plan = 'StateMachineAIRNG',
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
    Name = 'LandAntiAirStateMachineRNG',
    Plan = 'StateMachineAIRNG',
    GlobalSquads = {
        { categories.LAND * categories.ANTIAIR - categories.EXPERIMENTAL, 1, 2, 'attack', 'none' },
        { categories.LAND * categories.SCOUT - categories.EXPERIMENTAL, 0, 1, 'guard', 'none' },
    },
}

PlatoonTemplate {
    Name = 'LandCombatHoverStateMachineRNG',
    Plan = 'StateMachineAIRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.HOVER * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          4, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}

PlatoonTemplate {
    Name = 'LandCombatAmphibStateMachineRNG',
    Plan = 'StateMachineAIRNG', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * (categories.AMPHIBIOUS + categories.HOVER) - categories.ANTIAIR - categories.SCOUT - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          4, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
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
    Name = 'RNGAI LandAttack Spam',
    Plan = 'StateMachineAIRNG', -- The platoon function to use.
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
    Name = 'RNGAI LandAttack Small Ranged',
    Plan = 'StateMachineAIRNG', -- The platoon function to use.
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