--[[
    File    :   /lua/AI/PlattonTemplates/MicroAITemplates.lua
    Author  :   SoftNoob
    Summary :
        Responsible for defining a mapping from AIBuilders keys -> Plans (Plans === platoon.lua functions)
]]

PlatoonTemplate {
    Name = 'RNGAILandAttack',
    Plan = 'StrikeForceAI', -- The platoon function to use.
    GlobalSquads = {
        { categories.MOBILE * categories.LAND - categories.EXPERIMENTAL - categories.ENGINEER, -- Type of units.
          1, -- Min number of units.
          1, -- Max number of units.
          'scout', -- platoon types: 'support', 'attack', 'scout',
          'none' }, -- platoon move formations: 'None', 'AttackFormation', 'GrowthFormation',
    },
}