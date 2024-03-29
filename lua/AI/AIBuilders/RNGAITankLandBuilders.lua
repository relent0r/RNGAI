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
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueue',
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
    },
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
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueue',
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
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Reaction Tanks',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Tank Enemy Nearby',
        PlatoonTemplate = 'RNGAIT1LandResponse',
        Priority = 880,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Tank Enemy Nearby',
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
        BuilderName = 'RNGAI T3 Tank Enemy Nearby',
        PlatoonTemplate = 'RNGAIT3LandResponse',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Reaction Tanks Expansion',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Tank Enemy Nearby Expansion',
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
        BuilderName = 'RNGAI T2 Tank Enemy Nearby Expansion',
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
        BuilderName = 'RNGAI T3 Tank Enemy Nearby Expansion',
        PlatoonTemplate = 'RNGAIT3LandResponse',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 3, categories.LAND * categories.MOBILE * categories.DIRECTFIRE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land AA 2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Mobile AA Response',
        PlatoonTemplate = 'T1LandAA',
        Priority = 850,
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
    Builder {
        BuilderName = 'RNGAI Factory Land Expansion',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueExp',
        Priority = 700, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Expansion',
        PlatoonTemplate = 'RNGAIT2LandAttackQueueExp',
        Priority = 700,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Islands',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Land T1 Island Expansion',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueExp',
        Priority = 700, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { TBC, 'ThreatPresentInGraphRNG', {'LocationType', 'StructuresNotMex'} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.3, 'LAND'}},
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
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND - categories.ENGINEER - categories.EXPERIMENTAL } },
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
    BuilderGroupName = 'RNGAI Land FormBuilders Expansion Large',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1 Expansion Large',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 600,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) }}, -- stop building after we decent reach tech2 capability
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
            ThreatWeights = {
                IgnoreStrongerTargetsIfWeakerThan = 10, -- If the platoon is weaker than this threat level
                IgnoreStrongerTargetsRatio = 5, -- If platoon is weaker than the above threat then ignore stronger threats if stronger by this ratio. (so if they are 100?) 
                PrimaryThreatTargetType = 'StructuresNotMex', -- Primary type of threat to find targets
                SecondaryThreatTargetType = 'Land', -- Secondary type of threat to find targets
                SecondaryThreatWeight = 1,
                WeakAttackThreatWeight = 2, -- If the platoon is weaker than the target threat then decrease by this factor
                StrongAttackThreatWeight = 5, -- If the platoon is stronger than the target threat then increase by this factor
                VeryNearThreatWeight = 20, -- If the target is very close increase by this factor, default radius is 25
                NearThreatWeight = 10, -- If the target is close increase by this factor, default radius is 75
                MidThreatWeight = 5, -- If the target is mid range increase by this factor, default radius is 150
                FarThreatWeight = 1, -- if the target is far awat increase by this factor default radius is 300. There is also a VeryFar which is -1
                TargetCurrentEnemy = false, -- Take the current enemy into account when finding targets
                IgnoreCommanderStrength = false, -- Do we ignore the ACU's antisurface threat when picking an attack location
            },
        },         
    },
    Builder {
        BuilderName = 'RNGAI Mass Raid Expansions Large',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name.
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            StateMachine = 'ZoneControl',
            ZoneType     = 'raid',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            LocationType = 'LocationType',
            MaxPathDistance = 'BaseEnemyArea', -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 6000,			-- If threat is higher than this, do not attack
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
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common Expansion Large',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
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
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon Expansion Large',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatHoverStateMachineRNG',                          -- Template Name. 
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
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
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
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
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER } },
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
        BuilderName = 'RNGAI Response BaseMilitary ANTIAIR Area',
        PlatoonTemplate = 'LandAntiAirStateMachineRNG',
        Priority = 1000,
        InstanceCount = 3,
        BuilderType = 'Any',
        BuilderConditions = {
--            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.INDIRECTFIRE} },
              { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.INDIRECTFIRE} },
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
            PlatoonPlan = 'MercyAIRNG',
            Location = 'LocationType',
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
        BuilderName = 'RNGAI Zone Control',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            --{ UCBC, 'LessThanGameTimeSecondsRNG', { 300 } }, -- don't build after 5 minutes
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
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
        InstanceCount = 4,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
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
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
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
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * ( categories.AMPHIBIOUS + categories.HOVER ) - categories.ENGINEER - categories.EXPERIMENTAL } },
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
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
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
    BuilderGroupName = 'RNGAI Land FormBuilders Large',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Trueplatoon Large',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 690,                                                          -- Priority. 1000 is normal.
        InstanceCount = 8,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            StateMachine = 'LandCombat'
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Assault Large',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatStateMachineRNG',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
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
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
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
                categories.ALLUNITS - categories.NAVAL - categories.AIR,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Intelli Amphib Large',                              -- Random Builder Name.
        PlatoonTemplate = 'LandCombatAmphibStateMachineRNG',                          -- Template Name. 
        Priority = 710,                                                          -- Priority. 1000 is normal.
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * ( categories.AMPHIBIOUS + categories.HOVER ) - categories.ENGINEER - categories.EXPERIMENTAL}},
        },
        BuilderData = {
            StateMachine = 'LandAssault',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            PlatoonLimit = 15,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
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
            ThreatSupport = 2,
        },
    },
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2 Large',                              -- Random Builder Name.
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
            LocationType = 'LocationType',
            GetTargetsFromBase = false,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchPriorities = {
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
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
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1 Large',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 500,
        InstanceCount = 12,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'MAIN', 3, categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) }}, -- stop building after we decent reach tech2 capability
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
            ThreatWeights = {
                IgnoreStrongerTargetsIfWeakerThan = 10, -- If the platoon is weaker than this threat level
                IgnoreStrongerTargetsRatio = 5, -- If platoon is weaker than the above threat then ignore stronger threats if stronger by this ratio. (so if they are 100?) 
                PrimaryThreatTargetType = 'StructuresNotMex', -- Primary type of threat to find targets
                SecondaryThreatTargetType = 'Land', -- Secondary type of threat to find targets
                SecondaryThreatWeight = 1,
                WeakAttackThreatWeight = 2, -- If the platoon is weaker than the target threat then decrease by this factor
                StrongAttackThreatWeight = 5, -- If the platoon is stronger than the target threat then increase by this factor
                VeryNearThreatWeight = 20, -- If the target is very close increase by this factor, default radius is 25
                NearThreatWeight = 10, -- If the target is close increase by this factor, default radius is 75
                MidThreatWeight = 5, -- If the target is mid range increase by this factor, default radius is 150
                FarThreatWeight = 1, -- if the target is far awat increase by this factor default radius is 300. There is also a VeryFar which is -1
                TargetCurrentEnemy = false, -- Take the current enemy into account when finding targets
                IgnoreCommanderStrength = false, -- Do we ignore the ACU's antisurface threat when picking an attack location
            },
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
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL } },
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
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL } },
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
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
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
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
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
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER} },  	
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
