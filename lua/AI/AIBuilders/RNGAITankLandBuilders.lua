--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
LOG('* AI-RNG: BaseRestricted :'..BaseRestrictedArea..' BaseMilitary :'..BaseMilitaryArea..' BaseDMZArea :'..BaseDMZArea..' BaseEnemy :'..BaseEnemyArea)
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'

function LandAttackCondition(aiBrain, locationType, targetNumber)
    local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager

    local position = engineerManager:GetLocationCoords()
    local radius = engineerManager:GetLocationRadius()
    
    local poolThreat = pool:GetPlatoonThreat( 'Surface', categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, position, radius )
    if poolThreat > targetNumber then
        return true
    end
    return false
end

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder',
    BuildersType = 'FactoryBuilder',
    -- Opening Tank Build --
    Builder {
        BuilderName = 'RNGAI Factory Tank Sera', -- Sera only because they don't get labs
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 900, -- After First Engie Group and scout
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 240 } }, -- don't build after 4 minutes
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank 9',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 360 } }, -- don't build after 6 minutes
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Land Attack',
        PlatoonTemplate = 'RNGAIT1LandAttackQueue',
        Priority = 750, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatio', { 0.01, 0.1}},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 5, 'FACTORY LAND TECH2' }}, -- stop building after we decent reach tech2 capability
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Reaction Tanks',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Tank Enemy Nearby',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 880,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH2' }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.3, 0.5 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Tank Enemy Nearby',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.4, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T3 Tank Enemy Nearby',
        PlatoonTemplate = 'RNGAIT3LandResponse',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.8 }},
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
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.LAND * categories.ANTIAIR } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH2' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile AA Response',
        PlatoonTemplate = 'T2LandAA',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.LAND * categories.ANTIAIR } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH2' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}
-- Tech 2 Units
BuilderGroup {
    BuilderGroupName = 'RNGAI T2 TankLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Attack - Tech 2',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 760,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 4, 'FACTORY LAND TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.00 }},
            { EBC, 'GreaterThanEconStorageRatio', { 0.02, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T3 AttackLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Attack - Tech 3',
        PlatoonTemplate = 'RNGAIT3LandAttackQueue',
        Priority = 770,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.00 }},
            { EBC, 'GreaterThanEconStorageRatio', { 0.02, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Expansions',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Land Expansion',
        PlatoonTemplate = 'RNGAIT1LandAttackQueue',
        Priority = 700, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH2' }}, -- stop building after we decent reach tech2 capability
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconStorageRatio', { 0.01, 0.1}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Expansion',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 700,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.05 }},
            { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
}

-- Land Formers

BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders Expansion',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1 Expansion',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 600,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY TECH2, FACTORY TECH3' }}, -- stop building after we decent reach tech2 capability
            --{ LandAttackCondition, { 'LocationType', 10 } }, -- causing errors with expansions
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'AttackFormation',
        },        
        
    },
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T2 Expansion',
        PlatoonTemplate = 'RNGAI LandAttack Large T2',
        Priority = 600,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.TECH2 - categories.ENGINEER} },
            --{ LandAttackCondition, { 'LocationType', 50 } }, -- causing errors with expansions
        },
    },
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2 Expansion',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 4,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
        },
        BuilderData = {
            SearchRadius = 10000,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.STRUCTURE * categories.LAND * categories.MOBILE,         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'STRUCTURE DEFENSE',
                'MASSEXTRACTION',
                'ENERGYPRODUCTION',
                'STRUCTURE ANTIAIR',
                'COMMAND',
                'MASSFABRICATION',
                'SHIELD',
                'STRUCTURE',
                'ALLUNITS',
            },
            UseFormation = 'GrowthFormation',
        },
    },
    Builder {
        BuilderName = 'RNGAI Mass Raid Expansions',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 4900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = false,      
            AvoidClosestRadius = 100,
            UseFormation = 'AttackFormation',
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common Expansion',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Expansion',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            UseFormation = 'None',
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon Expansion',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            UseFormation = 'None',
            },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Response Formers',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Response BaseRestrictedArea',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        PlatoonAddBehaviors = { 'TacticalResponse' },
        Priority = 1000,                                                          -- Priority. 1000 is normal.
        InstanceCount = 6,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE - categories.SCOUT }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND - categories.ENGINEER - categories.INDIRECTFIRE} },
        },
        BuilderData = {
            SearchRadius = BaseRestrictedArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            LocationType = 'LocationType',
            Defensive = true,
            AttackEnemyStrength = 100,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MOBILE * categories.LAND - categories.SCOUT - categories.WALL ,         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'EXPERIMENTAL',
                'MOBILE LAND DIRECTFIRE',
                'MOBILE LAND INDIRECTFIRE',
                'ENGINEER',
                'STRUCTURE DEFENSE',
                'MOBILE LAND ANTIAIR',
                'STRUCTURE ANTIAIR',
                'ALLUNITS',
            },
            UseFormation = 'AttackFormation',
        },
    },
    Builder {
        BuilderName = 'RNGAI Response BaseMilitary ANTIAIR Area',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI Antiair Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 1000,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER - categories.SCOUT }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.INDIRECTFIRE} },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            LocationType = 'LocationType',
            Defensive = true,
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MOBILE * categories.LAND - categories.SCOUT - categories.WALL ,         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'MOBILE AIR BOMBER',
                'MOBILE AIR',
            },
            UseFormation = 'None',
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Start Location Attack Early',
        PlatoonTemplate = 'RNGAI T1 Guard Marker Small',
        Priority = 700,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER} },  	
            },
        BuilderData = {
            MarkerType = 'Start Location',            
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            IgnoreFriendlyBase = true,
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 30,
            AggressiveMove = true,      
            AvoidClosestRadius = 50,
            GuardTimer = 10,              
            UseFormation = 'AttackFormation',
        },    
    }, 
    Builder {
        BuilderName = 'RNGAI Spam Common',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 500,                                                          -- Priority. 1000 is normal.
        PlatoonAddBehaviors = { 'TacticalResponse' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            UseFormation = 'None',
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            UseFormation = 'None',
            },
    }, 
    Builder {
        BuilderName = 'RNGAI Ranged Attack',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 750,                                                          -- Priority. 1000 is normal.
        InstanceCount = 6,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 960 } }, -- don't build after 16 minutes
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE}},
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = (categories.STRUCTURE + categories.MOBILE ) * categories.LAND - categories.SCOUT - categories.WALL,         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'STRUCTURE DEFENSE',
                'MASSEXTRACTION',
                'STRUCTURE ANTIAIR',
                'STRUCTURE',
                'ENERGYPRODUCTION',
                'COMMAND',
                'MASSFABRICATION',
                'SHIELD',
                'ALLUNITS',
            },
            UseFormation = 'GrowthFormation',
        },
    },
    Builder {
        BuilderName = 'RNGAI Ranged Defense Attack BaseDMZArea',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { TBC, 'EnemyThreatGreaterThanValueAtBase', { 'MAIN', 5, 'Structures', 2 , 'RNGAI Ranged Defense Attack BaseDMZArea'} },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE }},
        },
        BuilderData = {
            SearchRadius = BaseDMZArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * categories.LAND),         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'DEFENSE STRUCTURE',
                'ANTIAIR STRUCTURE',
                'MASSEXTRACTION',
                'STRUCTURE',
                'ENERGYPRODUCTION',
                'COMMAND',
                'MASSFABRICATION',
                'SHIELD',
                'ALLUNITS',
            },
            UseFormation = 'GrowthFormation',
        },
    },
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 10,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = (categories.STRUCTURE + categories.MOBILE ) * categories.LAND - categories.SCOUT,         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'STRUCTURE DEFENSE',
                'MASSEXTRACTION',
                'ENERGYPRODUCTION',
                'STRUCTURE ANTIAIR',
                'COMMAND',
                'MASSFABRICATION',
                'SHIELD',
                'STRUCTURE',
                'ALLUNITS',
            },
            UseFormation = 'GrowthFormation',
        },
    },
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 400,
        InstanceCount = 12,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocation', { 'MAIN', 3, 'FACTORY TECH2, FACTORY TECH3' }}, -- stop building after we decent reach tech2 capability
            --{ LandAttackCondition, { 'LocationType', 10 } }, -- causing errors with expansions
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = false,
            UseFormation = 'AttackFormation',
        },        
        
    },
    Builder {
        BuilderName = 'RNGAI Unit Cap Default Land Attack',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 100,
        InstanceCount = 20,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND - categories.ENGINEER } },
            { UCBC, 'UnitCapCheckGreater', { .95 } },
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            ThreatWeights = {
                IgnoreStrongerTargetsRatio = 100.0,
            },
        },
    },
    
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T2',
        PlatoonTemplate = 'RNGAI LandAttack Large T2',
        Priority = 700,
        InstanceCount = 30,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'AttackFormation',
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.TECH2 - categories.ENGINEER} },
            --{ LandAttackCondition, { 'LocationType', 50 } }, -- causing errors with expansions
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Mass Raid',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Mass Raid Small',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 4900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = false,      
            AvoidClosestRadius = 100,
            UseFormation = 'AttackFormation',
            },
            DistressRange = 200,
            DistressReactionTime = 8,
            ThreatSupport = 1,
    },
    Builder {
        BuilderName = 'RNGAI Mass Raid Medium',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Raiders Medium',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 700,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = false,			-- Don't find high threat targets
            MaxThreatThreshold = 4900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 2000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = true,      
            AvoidClosestRadius = 50,
            UseFormation = 'NoFormation',
            },
    },
}
