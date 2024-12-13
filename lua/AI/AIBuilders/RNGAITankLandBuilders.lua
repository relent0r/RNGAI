--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'

local DefensivePosture = function(self, aiBrain, builderManager, builderData)
    local myExtractorCount = aiBrain.BrainIntel.SelfThreat.AllyExtractorCount
    local totalMassMarkers = aiBrain.BrainIntel.SelfThreat.MassMarker
    if myExtractorCount and totalMassMarkers then
        --RNGLOG('My Extractor Count '..myExtractorCount.. ' totalMassMarkers '..totalMassMarkers)
    end
    if myExtractorCount > (totalMassMarkers / 2) then
        --RNGLOG('Defensive : More than half the mass markers switch to defensive mode for '..aiBrain.Nickname)
        return 0
    end
    --RNGLOG('Defensive : return '..builderData.Priority)
    return builderData.Priority
end

local ACUClosePriority = function(self, aiBrain)
    if aiBrain.EnemyIntel.ACUEnemyClose then
        return 800
    else
        return 0
    end
end

local NoSmallFrys = function (self, aiBrain)
    if (aiBrain.BrainIntel.SelfThreat.LandNow + aiBrain.BrainIntel.SelfThreat.AllyLandThreat) * 1.2 > aiBrain.EnemyIntel.EnemyThreatCurrent.Land then
        return 0
    else
        return 700
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Small',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Initial Queue Small',
        PlatoonTemplate = 'InitialBuildQueueRNG',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSecondsRNG', { 120 } }, -- don't build after 6 minutes
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Small',
        PlatoonTemplate = 'T2LandAmphibious',
        Priority = 500, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    --[[
    Builder {
        BuilderName = 'RNGAI Factory T3 Amphib Attack Small',
        PlatoonTemplate = 'RNGAIT3AmphibAttackQueue',
        Priority = 550, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },]]
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Large',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Initial Queue Large',
        PlatoonTemplate = 'InitialBuildQueueRNG',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSecondsRNG', { 120 } }, -- don't build after 6 minutes
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Large',
        PlatoonTemplate = 'T2LandAmphibious',
        Priority = 550,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50, 'LAND'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    --[[
    Builder {
        BuilderName = 'RNGAI Factory T3 Amphib Attack Large',
        PlatoonTemplate = 'RNGAIT3AmphibAttackQueue',
        Priority = 555,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },]]
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Reaction Tanks',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Tank Response',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 880,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 5, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery Response',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 881,
        BuilderConditions = {
            { UCBC, 'EnemyStructuresGreaterThanMobileAtPerimeter', { 'LocationType' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Tank Response',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 MML Response',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 891,
        BuilderConditions = {
            { UCBC, 'EnemyStructuresGreaterThanMobileAtPerimeter', { 'LocationType' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Tank Response',
        PlatoonTemplate = 'T3LandBot',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Tank Enemy Armoured',
        PlatoonTemplate = 'T3ArmoredAssault',
        Priority = 910,
        BuilderConditions = {
            { UCBC, 'EnemyRangeGreaterThanAtRestricted', { 'LocationType', 30 }},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Arty Response',
        PlatoonTemplate = 'T3LandArtillery',
        Priority = 901,
        BuilderConditions = {
            { UCBC, 'EnemyStructuresGreaterThanMobileAtPerimeter', { 'LocationType' } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Reaction Tanks Expansion',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Tank Response Expansion',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 880,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery Response Expansion',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 881,
        BuilderConditions = {
            { UCBC, 'EnemyStructuresGreaterThanMobileAtPerimeter', { 'LocationType' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Tank Response Expansion',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 MML Response Expansion',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 891,
        BuilderConditions = {
            { UCBC, 'EnemyStructuresGreaterThanMobileAtPerimeter', { 'LocationType' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Tank Response Expansion',
        PlatoonTemplate = 'T3LandBot',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Tank Enemy Armoured Expansion',
        PlatoonTemplate = 'T3ArmoredAssault',
        Priority = 910,
        BuilderConditions = {
            { UCBC, 'EnemyRangeGreaterThanAtRestricted', { 'LocationType', 30 }},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Arty Response Expansion',
        PlatoonTemplate = 'T3LandArtillery',
        Priority = 901,
        BuilderConditions = {
            { UCBC, 'EnemyStructuresGreaterThanMobileAtPerimeter', { 'LocationType' } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land AntiAir Response',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Mobile AA Response',
        PlatoonTemplate = 'T1LandAA',
        Priority = 855,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'ANTISURFACEAIR' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.LAND * categories.ANTIAIR } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ANTIAIR } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile AA Response',
        PlatoonTemplate = 'T2LandAA',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'ANTISURFACEAIR' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.LAND * categories.ANTIAIR * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ANTIAIR * (categories.TECH2 + categories.TECH3) } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile AA Response',
        PlatoonTemplate = 'T3LandAA',
        Priority = 920,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'ANTISURFACEAIR' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.LAND * categories.ANTIAIR * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.LAND * categories.ANTIAIR * (categories.TECH2 + categories.TECH3) } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T3 AttackLandBuilder Small',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Mobile Arty ACUClose Small',
        PlatoonTemplate = 'T3LandArtillery',
        PriorityFunction = ACUClosePriority,
        Priority = 0,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.LAND * categories.MOBILE * categories.ARTILLERY * categories.TECH3 } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T3 AttackLandBuilder Large',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Mobile Arty ACUClose Large',
        PlatoonTemplate = 'T3LandArtillery',
        PriorityFunction = ACUClosePriority,
        Priority = 0,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.LAND * categories.MOBILE * categories.ARTILLERY * categories.TECH3 } },
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Large Unmarked',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Arty Sera Large Expansion', -- Sera cause floaty
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 500, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank Aeon Large Expansion', -- Aeon cause floaty
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 500, -- After First Engie Group and scout
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Islands',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Land T1 AntiAir Island Expansion',
        PlatoonTemplate = 'T1LandAA',
        Priority = 705, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Air'} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T1 Tank Island Expansion',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 705, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Land'} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T1 Artillery Island Expansion',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 710, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Defensive'} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T2 AntiAir Island Expansion',
        PlatoonTemplate = 'T2LandAA',
        Priority = 706, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Air'} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T2 Tank Island Expansion',
        PlatoonTemplate = 'T2LandAmphibious',
        Priority = 706, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Land'} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T2 MML Island Expansion',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 711, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Defensive'} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T3 AA Island Expansion',
        PlatoonTemplate = 'T3LandAA',
        Priority = 707, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Air'} },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T3 Tank Island Expansion',
        PlatoonTemplate = 'T3LandBot',
        Priority = 707, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Land'} },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land T3 Arty Island Expansion',
        PlatoonTemplate = 'T3LandArtillery',
        Priority = 712, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentOnLabelRNG', {'LocationType', 'Defensive'} },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}
-- Land Formers

BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders Expansion',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Mass Raid Expansions',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name.
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            StateMachine = 'ZoneControl',
            Avoid        = true,
            ZoneType     = 'raid',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            LocationType = 'LocationType',
            MaxPathDistance = 'BaseEnemyArea', -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = false,			-- Don't find high threat targets
            MaxThreatThreshold = 650,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 50,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 120,
            AggressiveMove = false,      
            AvoidClosestRadius = 5,
            UseFormation = 'AttackFormation',
            TargetSearchPriorities = { 
                categories.MOBILE * categories.LAND
            },
            SetWeaponPriorities = true,
            PrioritizedCategories = {
                categories.EXPERIMENTAL,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,   
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.ALLUNITS - categories.INSIGNIFICANTUNIT,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common Expansion Small',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.DEFENSE,
                categories.FACTORY,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common Expansion Quick Small',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 5,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            StateMachine = 'LandCombat'
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon Expansion',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatHoverStateMachineRNG',                          -- Template Name. 
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.FACTORY,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
        },
    },
}


BuilderGroup {
    BuilderGroupName = 'RNGAI Land Response Formers',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    --[[
    Builder {
        BuilderName = 'RNGAI Land Feeder',
        PlatoonTemplate = 'RNGAI LandFeeder',
        Priority = 400,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderData = {
            PlatoonType = 'tank',
            PlatoonSearchRange = 'BaseDMZArea',
            Avoid = true,
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            NeverGuardEngineers = true,
            PlatoonLimit = 18,
            PrioritizedCategories = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MOBILE * categories.LAND,
                categories.ALLUNITS - categories.INSIGNIFICANTUNIT,
            },
        },
        BuilderConditions = {
            { UCBC, 'PlatoonTemplateExist', { 'RNGAI Zone Control' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE } },
            { UCBC, 'EnemyUnitsLessAtRestrictedRNG', { 'LocationType', 1, 'LAND' }},
         },
    },]]
    Builder {
        BuilderName = 'RNGAI Response BaseRestrictedArea',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 1000,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.SCOUT } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            Defensive = true,
            SearchRadius = 'BaseEnemyArea',
            StateMachine = 'LandCombat'
        },
    },
    Builder {
        BuilderName = 'RNGAI ZoneControl BaseMilitary ANTIAIR Area',
        PlatoonTemplate = 'LandAntiAirStateMachineRNG',
        Priority = 1000,
        InstanceCount = 30,
        BuilderType = 'Any',
        BuilderConditions = {
              { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.INDIRECTFIRE} },
              --{ UCBC, 'PlatoonDemandMet', { 'Land', 'aa' } },
        },
        BuilderData = {
            StateMachine = 'ZoneControlDefense',
            ZoneType     = 'aadefense',
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.AIR
            },
            PrioritizedCategories = {
                categories.AIR
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Response MobileBomb Area',
        PlatoonTemplate = 'RNGAI MobileBombAttack',
        Priority = 1000,
        InstanceCount = 3,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.xrl0302 } },
        },
        BuilderData = {
            StateMachine = 'MobileBomb',
            LocationType = 'LocationType',
            SearchRadius = 'BaseEnemyArea',
            PrioritizedCategories = {
                categories.COMMAND,
                categories.LAND * categories.EXPERIMENTAL,
            },
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Lab Early Game',
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Mini',
        Priority = 1000,
        InstanceCount = 3,
        BuilderConditions = {  
                { MIBC, 'LessThanGameTime', { 300 } },
                { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.SCOUT } },
            },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'ZoneControl',
            ZoneType     = 'raid',
            UseFormation = 'None',
            LocationType = 'LocationType',
            EarlyRaid = true,
            TargetSearchPriorities = { 
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
            },
            PrioritizedCategories = {   
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
            },
        },    
    },
    Builder {
        BuilderName = 'RNGAI Zone Control',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 5,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT } },
        },
        BuilderData = {
            StateMachine = 'ZoneControl',
            ZoneType     = 'control',
            UseFormation = 'None',
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ALLUNITS,
            },
            },
    },

    Builder {
        BuilderName = 'RNGAI Trueplatoon',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 700,                                                          -- Priority. 1000 is normal.
        InstanceCount = 5,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT  } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            StateMachine = 'LandCombat'
            },
    },
    
    Builder {
        BuilderName = 'RNGAI Spam Assault',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT  } },
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Intelli Amphib',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatAmphibStateMachineRNG',                          -- Template Name. 
        Priority = 710,                                                          -- Priority. 1000 is normal.
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * ( categories.AMPHIBIOUS + categories.HOVER ) - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT  } },
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            TargetSearchPriorities = {
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.ALLUNITS,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam',                          -- Template Name. 
        Priority = 500,                                                          -- Priority. 1000 is normal.
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 6, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT  } },
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
        },
        BuilderData = {
            StateMachine = 'ZoneControl',
            UseFormation = 'None',
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.ALLUNITS,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. 
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 10,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            RangedAttack = true,
            SearchRadius = 'BaseEnemyArea',                                               -- Searchradius for new target.
            GetTargetsFromBase = false,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.STRUCTURE * categories.DEFENSE,
                categories.EXPERIMENTAL * categories.LAND,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.STRUCTURE * categories.DEFENSE,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.COMMAND,
                categories.MASSFABRICATION,
                categories.SHIELD,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            UseFormation = 'GrowthFormation',
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 5,
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Island Large FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Sera Arty Island',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatHoverStateMachineRNG',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 4 }},
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT  } },
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
        },
    },
    Builder {
        BuilderName = 'RNGAI Aeon Tanks Island',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatHoverStateMachineRNG',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }},
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT  } },
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land Mass Raid',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Mass Raid Small',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 700,                                                          -- Priority. 1000 is normal.
        PriorityFunction = NoSmallFrys,
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.SCOUT  } },
        },
        BuilderData = {
            StateMachine = 'ZoneControl',
            Avoid        = true,
            ZoneType     = 'raid',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = 'BaseEnemyArea', -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            AggressiveMove = false,      
            UseFormation = 'AttackFormation',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            SetWeaponPriorities = true,
            PrioritizedCategories = {   
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.SCOUT,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.ALLUNITS - categories.INSIGNIFICANTUNIT,
            },
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
    },
    Builder {
        BuilderName = 'RNGAI Mass Raid Medium',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name.
        Priority = 610,                                                          -- Priority. 1000 is normal.
        PriorityFunction = DefensivePosture,
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.SCOUT  } },
        },
        BuilderData = {
            StateMachine = 'ZoneControl',
            Avoid        = true,
            ZoneType     = 'raid',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = 'BaseEnemyArea', -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            AggressiveMove = false,      
            UseFormation = 'NoFormation',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            SetWeaponPriorities = true,
            PrioritizedCategories = {   
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.SCOUT,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.ALLUNITS - categories.INSIGNIFICANTUNIT,
            },
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
    },
    Builder {
        BuilderName = 'RNGAI Mass Raid Large',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name.
        Priority = 600,                                                          -- Priority. 1000 is normal.
        PriorityFunction = DefensivePosture,
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.SCOUT } },  	
        },
        BuilderData = {
            StateMachine = 'ZoneControl',
            ZoneType     = 'raid',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = 'BaseEnemyArea', -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            AggressiveMove = true,      
            UseFormation = 'NoFormation',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
                categories.ALLUNITS,
            },
            SetWeaponPriorities = true,
            PrioritizedCategories = {   
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.SCOUT,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.ALLUNITS - categories.INSIGNIFICANTUNIT,
            },
            },
    },
}
