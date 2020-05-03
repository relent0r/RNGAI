local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local MaxAttackForce = 0.45

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Builders T1',                               
    BuildersType = 'FactoryBuilder',
    -- TECH 1
    Builder {
        BuilderName = 'RNGAI Sea T1 Sub Response',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 900,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, unitCount, categoryEnemy
            -- Do we need additional conditions to build it ?
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 40,  categories.MOBILE * categories.NAVAL } },
            -- Have we the eco to build it ?
            -- Don't build it if...
            { UCBC, 'UnitsGreaterAtEnemy', { 2 , categories.NAVAL * categories.FACTORY } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea T1 Frig Response',
        PlatoonTemplate = 'T1SeaAntiAir',
        Priority = 900,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR * ( categories.BOMBER + categories.GROUNDATTACK + categories.ANTINAVY ) }}, -- radius, LocationType, unitCount, categoryEnemy
            -- Do we need additional conditions to build it ?
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 40,  categories.MOBILE * categories.NAVAL } },
            -- Have we the eco to build it ?
            -- Don't build it if...
            { UCBC, 'UnitsGreaterAtEnemy', { 2 , categories.NAVAL * categories.FACTORY } },
        },
        BuilderType = 'Sea',
    },

    Builder {
        BuilderName = 'RNGAI Sub',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 150,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }}, -- LocationType, categoryUnits
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            -- When do we want to build this ?
            { UCBC, 'UnitsGreaterAtEnemy', { 0 , categories.NAVAL * categories.FACTORY } },
            --{ UCBC, 'HaveUnitRatioVersusEnemy', { 1.0, categories.MOBILE * categories.NAVAL, '<=', categories.MOBILE * categories.NAVAL } },
            --{ UCBC, 'NavalBaseWithLeastUnitsRNG', {  60, 'LocationType', categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, categoryUnits
            -- Respect UnitCap
            --{ UCBC, 'HaveUnitRatioVersusCap', { MaxAttackForce , '<=', categories.MOBILE } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea Frigate',
        PlatoonTemplate = 'T1SeaFrigate',
        Priority = 150,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }}, -- LocationType, categoryUnits
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            -- When do we want to build this ?
            { UCBC, 'UnitsGreaterAtEnemy', { 0 , categories.NAVAL * categories.FACTORY } },
            --{ UCBC, 'HaveUnitRatioVersusEnemy', { 1.0, categories.MOBILE * categories.NAVAL, '<=', categories.MOBILE * categories.NAVAL } },
            --{ UCBC, 'NavalBaseWithLeastUnitsRNG', {  60, 'LocationType', categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, categoryUnits
            -- Respect UnitCap
            --{ UCBC, 'HaveUnitRatioVersusCap', { MaxAttackForce , '<=', categories.MOBILE } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea Frigate Initial',
        PlatoonTemplate = 'T1SeaFrigate',
        Priority = 500,
        BuilderConditions = {
            -- Have we the eco to build it ?
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.MOBILE * categories.NAVAL * categories.TECH1 * categories.FRIGATE } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            -- When do we want to build this ?
            --{ UCBC, 'HaveUnitRatioVersusEnemy', { 1.0, categories.MOBILE * categories.NAVAL, '<=', categories.MOBILE * categories.NAVAL } },
            --{ UCBC, 'NavalBaseWithLeastUnitsRNG', {  60, 'LocationType', categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, categoryUnits
            -- Respect UnitCap
            --{ UCBC, 'HaveUnitRatioVersusCap', { MaxAttackForce , '<=', categories.MOBILE } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea Sub Initial',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.MOBILE * categories.NAVAL * categories.TECH1 * categories.SUBMERSIBLE } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            --{ UCBC, 'HaveUnitRatioVersusEnemy', { 1.0, categories.MOBILE * categories.NAVAL, '<=', categories.MOBILE * categories.NAVAL } },
            --{ UCBC, 'NavalBaseWithLeastUnitsRNG', {  60, 'LocationType', categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, categoryUnits
            -- Respect UnitCap
            --{ UCBC, 'HaveUnitRatioVersusCap', { MaxAttackForce , '<=', categories.MOBILE } },
        },
        BuilderType = 'Sea',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Builders T23',                               
    BuildersType = 'FactoryBuilder',
    Builder { 
        BuilderName = 'RNGAI Destroyer Initial',
        PlatoonTemplate = 'T2SeaDestroyer',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.DESTROYER } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Destroyer Response',
        PlatoonTemplate = 'T2SeaDestroyer',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 2, categories.MOBILE * categories.NAVAL * categories.DESTROYER }}, -- radius, LocationType, unitCount, categoryEnemy
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },

    Builder { 
        BuilderName = 'RNGAI Cruiser Initial',
        PlatoonTemplate = 'T2SeaCruiser',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.CRUISER } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Cruiser Response',
        PlatoonTemplate = 'T2SeaCruiser',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 2, categories.MOBILE * categories.AIR * (categories.ANTINAVY + categories.GROUNDATTACK) }}, -- radius, LocationType, unitCount, categoryEnemy
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },

    Builder { 
        BuilderName = 'RNGAI SubKiller Initial',
        PlatoonTemplate = 'T2SubKiller',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.T2SUBMARINE } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI SubKiller Response',
        PlatoonTemplate = 'T2SubKiller',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 2, categories.MOBILE * categories.NAVAL }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI ShieldBoat Initial',
        PlatoonTemplate = 'T2ShieldBoat',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.SHIELD } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI CounterIntel Initial',
        PlatoonTemplate = 'T2CounterIntelBoat',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.STEALTH } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Sea T2 Queue',
        PlatoonTemplate = 'RNGAIT2SeaAttackQueue',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.08, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Sea T3 Queue',
        PlatoonTemplate = 'RNGAIT3SeaAttackQueue',
        Priority = 450,
        BuilderConditions = {
            { UCBC, 'FactoryGreaterAtLocation', { 'LocationType', 0, 'FACTORY NAVAL TECH3' }},
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLessRNG', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Frequent Sea Attack T1',
        PlatoonTemplate = 'RNGAI Sea Attack T1',
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        Priority = 300,
        InstanceCount = 20,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.NAVAL * categories.TECH1 * (categories.SUBMERSIBLE + categories.DIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
            --{ SeaAttackCondition, { 'LocationType', 14 } },
        },
        BuilderData = {
            UseFormation = 'AttackFormation',
            ThreatWeights = {
                IgnoreStrongerTargetsRatio = 100.0,
                PrimaryThreatTargetType = 'Naval',
                SecondaryThreatTargetType = 'Economy',
                SecondaryThreatWeight = 1,
                WeakAttackThreatWeight = 1,
                VeryNearThreatWeight = 10,
                NearThreatWeight = 5,
                MidThreatWeight = 1,
                FarThreatWeight = 1,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Frequent Sea Attack T23',
        PlatoonTemplate = 'RNGAI Sea Attack T123',
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        Priority = 300,
        InstanceCount = 20,
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'NAVAL', categories.MOBILE * (categories.TECH2 + categories.TECH3) * categories.NAVAL * (categories.SUBMERSIBLE + categories.DIRECTFIRE) - categories.ENGINEER} },
            --{ SeaAttackCondition, { 'LocationType', 14 } },
        },
        BuilderData = {
            UseFormation = 'AttackFormation',
            ThreatWeights = {
                IgnoreStrongerTargetsRatio = 100.0,
                PrimaryThreatTargetType = 'Naval',
                SecondaryThreatTargetType = 'Economy',
                SecondaryThreatWeight = 1,
                WeakAttackThreatWeight = 1,
                VeryNearThreatWeight = 10,
                NearThreatWeight = 5,
                MidThreatWeight = 1,
                FarThreatWeight = 1,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Sea Hunters',
        PlatoonTemplate = 'RNGAI Sea Hunt',
        --PlatoonAddPlans = {'DistressResponseAI'},
        Priority = 300,
        InstanceCount = 20,
        BuilderType = 'Any',
        BuilderData = {
        UseFormation = 'GrowthFormation',
        },
        BuilderConditions = {
            -- Change to NUKESUB once the Cybran BP is updated
            { UCBC, 'ScalePlatoonSize', { 'LocationType', 'NAVAL', categories.MOBILE * categories.NAVAL * (categories.SUBMERSIBLE + categories.xes0102) - categories.ENGINEER - categories.EXPERIMENTAL - categories.NUKE } },
            --{ SeaAttackCondition, { 'LocationType', 20 } },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Hunter Sea Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Sea Mass Raid',
        PlatoonTemplate = 'RNGAI Sea Mass Raid T1',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {  
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1 }},
                { MIBC, 'MassMarkersInWater', {} },
            },
        BuilderData = {
            MarkerType = 'Mass',            
            WaterOnly = true,
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            ThreatType = 'Economy',			    -- Type of threat to use for gauging attacks
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 2900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,			-- If threat is lower than this, do not attack
            AvoidBases = false,
            AvoidBasesRadius = 75,
            AggressiveMove = true,      
            AvoidClosestRadius = 50, 
        },    
        BuilderType = 'Any',
    },
}