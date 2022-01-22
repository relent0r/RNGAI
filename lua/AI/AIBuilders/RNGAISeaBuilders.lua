local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local MaxAttackForce = 0.45
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local SeaDefenseMode = function(self, aiBrain, manager)
    local mySubThreat = aiBrain.BrainIntel.SelfThreat.NavalSubNow
    local enemySubThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.NavalSub
    if mySubThreat < enemySubThreat then
        --RNGLOG('Enable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 890
    else
        --RNGLOG('Disable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 0
    end
end

local SeaDefenseForm = function(self, aiBrain, manager)
    local mySubThreat = aiBrain.BrainIntel.SelfThreat.NavalSubNow
    local enemySubThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.NavalSub
    if mySubThreat < enemySubThreat then
        --RNGLOG('Enable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 350
    else
        --RNGLOG('Disable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 300
    end
end

local SeaRangedMode = function(self, aiBrain)
    if aiBrain.EnemyIntel.NavalRange.Range > 0 and aiBrain.EnemyIntel.NavalRange.Range < 165 then
        --RNGLOG('Enable Ranged Naval Builder')
        return 500
    else
        --RNGLOG('Disable Ranged Naval Builder')
        return 0
    end
end



BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Builders T1',                               
    BuildersType = 'FactoryBuilder',
    -- TECH 1
    Builder {
        BuilderName = 'RNGAI Sea T1 Sub Response',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 840,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'NAVAL' }},
            --{ UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, unitCount, categoryEnemy
            { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 10,  categories.MOBILE * categories.NAVAL } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.9 }},
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea T1 Frig Response',
        PlatoonTemplate = 'T1SeaAntiAir',
        Priority = 840,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'ANTISURFACEAIR' }},
            --{ UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR * ( categories.BOMBER + categories.GROUNDATTACK + categories.ANTINAVY ) }}, -- radius, LocationType, unitCount, categoryEnemy
            { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 10,  categories.MOBILE * categories.NAVAL } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.9 }},
        },
        BuilderType = 'Sea',
    },

    Builder {
        BuilderName = 'RNGAI Sea Attack Queue',
        PlatoonTemplate = 'RNGAIT1SeaAttackQueue',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }}, -- LocationType, categoryUnits
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.70 } },
            { UCBC, 'UnitsGreaterAtEnemyRNG', { 0 , categories.NAVAL * categories.FACTORY } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI T1 Frigate',
        PlatoonTemplate = 'T1SeaFrigate',
        Priority = 749,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL, true }},
            { EBC, 'FactorySpendRatioRNG', {'Naval', true}},
            { UCBC, 'ArmyManagerBuild', { 'Naval', 'T1', 'frigate'} },
            --{ EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            --{ EBC, 'GreaterThanEconEfficiencyRNG', { 0.75, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI Sea Frigate Initial',
        PlatoonTemplate = 'T1SeaFrigate',
        Priority = 500,
        BuilderConditions = {
            -- Have we the eco to build it ?
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH1 * categories.FRIGATE } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.50 } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea Sub Initial',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH1 * categories.SUBMERSIBLE } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Factory Sub Enemy Threat T1',
        PlatoonTemplate = 'RNGAIT1SeaSubQueue',
        Priority = 0,
        PriorityFunction = SeaDefenseMode,
        BuilderConditions = { 
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.NAVAL * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.6}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.DESTROYER } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI T2 Destroyer',
        PlatoonTemplate = 'T2SeaDestroyer',
        Priority = 750,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'FactorySpendRatioRNG', {'Naval', true}},
            { UCBC, 'ArmyManagerBuild', { 'Naval', 'T2', 'destroyer'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder { 
        BuilderName = 'RNGAI Cruiser Initial',
        PlatoonTemplate = 'T2SeaCruiser',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.CRUISER } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI SubKiller Initial',
        PlatoonTemplate = 'T2SubKiller',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.T2SUBMARINE } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI ShieldBoat Initial',
        PlatoonTemplate = 'T2ShieldBoat',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.SHIELD } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI CounterIntel Initial',
        PlatoonTemplate = 'T2CounterIntelBoat',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.MOBILE * categories.NAVAL * categories.TECH2 * categories.COUNTERINTELLIGENCE } }, -- Build engies until we have 3 of them.
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Factory Sub Enemy Threat T2',
        PlatoonTemplate = 'RNGAIT2SeaSubQueue',
        Priority = 0,
        PriorityFunction = SeaDefenseMode,
        BuilderConditions = { 
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.6}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Sea T2 Queue',
        PlatoonTemplate = 'RNGAIT2SeaAttackQueue',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Sea Ranged T2 Queue',
        PlatoonTemplate = 'RNGAIT2SeaAttackRangedQueue',
        Priority = 0,
        PriorityFunction = SeaRangedMode,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Factory Sub Enemy Threat T3',
        PlatoonTemplate = 'RNGAIT3SeaSubQueue',
        Priority = 0,
        PriorityFunction = SeaDefenseMode,
        BuilderConditions = { 
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Sea T3 Queue',
        PlatoonTemplate = 'RNGAIT3SeaAttackQueue',
        Priority = 501,
        BuilderConditions = {
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
    Builder { 
        BuilderName = 'RNGAI Sea Ranged T3 Queue',
        PlatoonTemplate = 'RNGAIT3SeaAttackRangedQueue',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1, 2, 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.NAVAL * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.MOBILE * categories.NAVAL * categories.NUKE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'UnitCapCheckLess', { 0.95 } },
        },
        BuilderType = 'Sea',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Intelli Sea Attack T1',
        PlatoonTemplate = 'RNGAI Intelli Sea Attack T1',
        Priority = 300,
        InstanceCount = 20,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.NAVAL * categories.TECH1 * (categories.SUBMERSIBLE + categories.DIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
            --{ SeaAttackCondition, { 'LocationType', 14 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            DistressRange = 180,
            UseFormation = 'None',
            AggressiveMove = false,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.NAVAL,
                categories.STRUCTURE * categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.ALLUNITS,
            },
        },
        BuilderType = 'Any',
    },
    --[[Builder {
        BuilderName = 'RNGAI Frequent Sea Attack T1',
        PlatoonTemplate = 'RNGAI Sea Attack T1',
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        Priority = 300,
        InstanceCount = 20,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.NAVAL * categories.TECH1 * (categories.SUBMERSIBLE + categories.DIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
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
    },]]
    --[[Builder {
        BuilderName = 'RNGAI Frequent Sea Attack T23',
        PlatoonTemplate = 'RNGAI Sea Attack T123',
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        Priority = 300,
        InstanceCount = 20,
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'NAVAL', categories.MOBILE * categories.NAVAL * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.ENGINEER} },
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
    },]]
    Builder {
        BuilderName = 'RNGAI Intelli Sea Attack T23',
        PlatoonTemplate = 'RNGAI Intelli Sea Attack T123',
        Priority = 310,
        InstanceCount = 20,
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'NAVAL', categories.MOBILE * categories.NAVAL * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.ENGINEER} },
            --{ SeaAttackCondition, { 'LocationType', 14 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            DistressRange = 180,
            UseFormation = 'None',
            AggressiveMove = false,
            ThreatSupport = 5,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.NAVAL,
                categories.STRUCTURE * categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.ALLUNITS,
            },
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Ranged Sea Attack T23',
        PlatoonTemplate = 'RNGAI Sea Attack Ranged T123',
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        Priority = 310,
        InstanceCount = 8,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.NAVAL * ( categories.TECH2 + categories.TECH3 ) * ( categories.CRUISER + categories.xas0306 + categories.NUKE ) - categories.EXPERIMENTAL } },
            --{ SeaAttackCondition, { 'LocationType', 14 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = false,
            ThreatSupport = 5,
            TargetSearchPriorities = {
                categories.STRUCTURE * categories.NAVAL * categories.FACTORY,
                categories.ENERGYPRODUCTION * categories.TECH3,
                categories.MASSEXTRACTION,
                categories.ENERGYSTORAGE,
                categories.ENERGYPRODUCTION,
                categories.MASSFABRICATION,
                categories.STRUCTURE,
            },
            PrioritizedCategories = {
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.COMMAND,
                categories.STRUCTURE,
            },
        },
        BuilderType = 'Any',
    },

    Builder {
        BuilderName = 'RNGAI Sea Hunters',
        PlatoonTemplate = 'RNGAI Sea Hunt',
        PlatoonAddPlans = {'DistressResponseAIRNG'},
        Priority = 310,
        PriorityFunction = SeaDefenseForm,
        InstanceCount = 20,
        BuilderType = 'Any',
        BuilderData = {
        UseFormation = 'GrowthFormation',
        },
        BuilderConditions = {
            -- Change to NUKESUB once the Cybran BP is updated
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.NAVAL * categories.ANTINAVY - categories.ENGINEER - categories.EXPERIMENTAL - categories.NUKE } },
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
            { MIBC, 'MassMarkersInWater', {} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1 }},
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
            TargetSearchPriorities = { 
                categories.MASSEXTRACTION,
                categories.MOBILE * categories.NAVAL
            },
            PrioritizedCategories = {   
                categories.MOBILE * categories.NAVAL,
                categories.STRUCTURE * categories.ANTINAVY,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.NAVAL,
                categories.COMMAND,
                categories.EXPERIMENTAL * categories.MOBILE
            },
        },    
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Sea Mass Raid Frigate',
        PlatoonTemplate = 'RNGAI Sea Mass Raid T1 Frigate',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {  
            { MIBC, 'FrigateRaidTrue', {} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MOBILE * categories.NAVAL * categories.FRIGATE * categories.TECH1 }},
            },
        BuilderData = {
            MarkerType = 'Mass',            
            FrigateRaid = true,
            WaterOnly = false,
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
            TargetSearchPriorities = { 
                categories.MASSEXTRACTION,
                categories.MOBILE * categories.NAVAL
            },
            PrioritizedCategories = {   
                categories.MOBILE * categories.NAVAL,
                categories.STRUCTURE * categories.ANTINAVY,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.NAVAL,
                categories.COMMAND,
                categories.EXPERIMENTAL * categories.MOBILE
            },
        },    
        BuilderType = 'Any',
    },
}