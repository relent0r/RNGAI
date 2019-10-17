--[[
    File    :   /lua/AI/PlattonTemplates/MicroAITemplates.lua
    Author  :   SoftNoob
    Summary :
        Responsible for defining a mapping from AIBuilders keys -> Plans (Plans === platoon.lua functions)
]]

PlatoonTemplate {
    Name = 'RNGAI T1 Mass Hunters Category',
    Plan = 'GuardMarker',    
    GlobalSquads = {
        { categories.TECH1 * categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.BOT - categories.SCOUT - categories.ENGINEER - categories.EXPERIMENTAL, 1, 3, 'attack', 'none' },
        { categories.LAND * categories.SCOUT, 0, 1, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Small',
    Plan = 'StrikeForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          1, -- Min number of units.
          3, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Small Ranged',
    Plan = 'StrikeForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND * categories.INDIRECTFIRE - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          1, -- Min number of units.
          4, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Medium',
    Plan = 'StrikeForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          4, -- Min number of units.
          12, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'None' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}

PlatoonTemplate {
    Name = 'RNGAI LandAttack Large',
    Plan = 'AttackForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          6, -- Min number of units.
          25, -- Max number of units.
          'attack', -- platoon types: 'support', 'attack', 'scout',
          'GrowthFormation' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}