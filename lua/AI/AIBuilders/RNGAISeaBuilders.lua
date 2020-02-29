local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local MaxAttackForce = 0.45

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Builders',                               
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
            { UCBC, 'CanPathNavalBaseToNavalTargets', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }}, -- LocationType, categoryUnits
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            -- When do we want to build this ?
            { UCBC, 'UnitsGreaterAtEnemy', { 0 , categories.NAVAL * categories.FACTORY } },
            --{ UCBC, 'HaveUnitRatioVersusEnemy', { 1.0, categories.MOBILE * categories.NAVAL, '<=', categories.MOBILE * categories.NAVAL } },
            --{ UCBC, 'NavalBaseWithLeastUnits', {  60, 'LocationType', categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, categoryUnits
            -- Respect UnitCap
            --{ UCBC, 'HaveUnitRatioVersusCap', { MaxAttackForce , '<=', categories.MOBILE } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea Frigate ratio',
        PlatoonTemplate = 'T1SeaFrigate',
        Priority = 150,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargets', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }}, -- LocationType, categoryUnits
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            -- When do we want to build this ?
            { UCBC, 'UnitsGreaterAtEnemy', { 0 , categories.NAVAL * categories.FACTORY } },
            --{ UCBC, 'HaveUnitRatioVersusEnemy', { 1.0, categories.MOBILE * categories.NAVAL, '<=', categories.MOBILE * categories.NAVAL } },
            --{ UCBC, 'NavalBaseWithLeastUnits', {  60, 'LocationType', categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, categoryUnits
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
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH1 } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconTrend', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            -- When do we want to build this ?
            --{ UCBC, 'HaveUnitRatioVersusEnemy', { 1.0, categories.MOBILE * categories.NAVAL, '<=', categories.MOBILE * categories.NAVAL } },
            --{ UCBC, 'NavalBaseWithLeastUnits', {  60, 'LocationType', categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, categoryUnits
            -- Respect UnitCap
            --{ UCBC, 'HaveUnitRatioVersusCap', { MaxAttackForce , '<=', categories.MOBILE } },
        },
        BuilderType = 'Sea',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Frequent Sea Attack T1',
        PlatoonTemplate = 'SeaAttack',
        Priority = 1,
        InstanceCount = 10,
        BuilderType = 'Any',
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
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, 'MOBILE TECH2 NAVAL, MOBILE TECH3 NAVAL' } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, 'MOBILE NAVAL SUB' } },
            --{ SeaAttackCondition, { 'LocationType', 14 } },
        },
    },
}