local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
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
    if mySubThreat < enemySubThreat * 1.1 then
        --RNGLOG('Enable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 350
    else
        --RNGLOG('Disable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 300
    end
end

local EnemyNavalAvailable = function(self, aiBrain, manager)
    if aiBrain.EnemyIntel.EnemyThreatCurrent.Naval > 0 then
        return 500
    end
    return 0
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
            { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 10,  categories.MOBILE * categories.NAVAL } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea T1 Frig Response',
        PlatoonTemplate = 'T1SeaAntiAir',
        Priority = 840,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'ANTISURFACEAIR' }},
            { UCBC, 'LessThanFactoryCountRNG', { 2, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 10,  categories.MOBILE * categories.NAVAL } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
        },
        BuilderType = 'Sea',
    },

    Builder {
        BuilderName = 'RNGAI T1 Frigate',
        PlatoonTemplate = 'T1SeaFrigate',
        Priority = 747,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL, true }},
            { EBC, 'FactorySpendRatioRNG', {'Naval', 'NavalUpgrading', true}},
            { UCBC, 'ArmyManagerBuild', { 'Naval', 'T1', 'frigate'} },
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
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH1 * categories.FRIGATE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.0, 0.10 } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea Sub Initial',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 0,
        PriorityFunction =  EnemyNavalAvailable,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL * categories.TECH1 * categories.SUBMERSIBLE } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.0, 0.10 } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Factory Sub Enemy Threat T1',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 0,
        PriorityFunction = SeaDefenseMode,
        BuilderConditions = { 
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.NAVAL * categories.TECH2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.20}},
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
            { EBC, 'FactorySpendRatioRNG', {'Naval','NavalUpgrading',  true}},
            { UCBC, 'ArmyManagerBuild', { 'Naval', 'T2', 'destroyer'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Cruiser',
        PlatoonTemplate = 'T2SeaCruiser',
        Priority = 749,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'FactorySpendRatioRNG', {'Naval','NavalUpgrading',  true}},
            { UCBC, 'ArmyManagerBuild', { 'Naval', 'T2', 'cruiser'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Cruiser Demand',
        PlatoonTemplate = 'T2SeaCruiser',
        Priority = 789,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Naval', 'T2', 'cruiser'} },
            { EBC, 'FactorySpendRatioRNG', {'Naval','NavalUpgrading',  true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Subhunter',
        PlatoonTemplate = 'T2SubKiller',
        Priority = 748,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'FactorySpendRatioRNG', {'Naval','NavalUpgrading',  true}},
            { UCBC, 'ArmyManagerBuild', { 'Naval', 'T2', 'subhunter'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 2
        },
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
        PlatoonTemplate = 'T2SubKiller',
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
        BuilderName = 'RNGAI T3 Battleship',
        PlatoonTemplate = 'T3SeaBattleship',
        Priority = 751,
        BuilderConditions = {
            { UCBC, 'CanPathNavalBaseToNavalTargetsRNG', {  'LocationType', categories.STRUCTURE * categories.FACTORY * categories.NAVAL }},
            { EBC, 'FactorySpendRatioRNG', {'Naval','NavalUpgrading',  true}},
            { UCBC, 'ArmyManagerBuild', { 'Naval', 'T3', 'battleship'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI Factory Sub Enemy Threat T3',
        PlatoonTemplate = 'T3SubKiller',
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
        BuilderName = 'RNGAI T3 MissileShip Demand',
        PlatoonTemplate = 'T3MissileBoat',
        Priority = 792,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Naval', 'T3', 'missileship'} },
            { EBC, 'FactorySpendRatioRNG', {'Naval', 'NavalUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 NukeSub Demand',
        PlatoonTemplate = 'T3SeaNukeSub',
        Priority = 791,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Naval', 'T3', 'nukesub'} },
            { EBC, 'FactorySpendRatioRNG', {'Naval', 'NavalUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Sea',
        BuilderData = {
            TechLevel = 3
        },
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
            StateMachine = 'NavalZoneControl',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            DistressRange = 180,
            UseFormation = 'None',
            AggressiveMove = false,
            ThreatSupport = 5,
            PlatoonLimit = 20,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.MASSFABRICATION,
                categories.ANTINAVY * categories.STRUCTURE,
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
        BuilderName = 'RNGAI Intelli Sea Attack T23',
        PlatoonTemplate = 'RNGAI Intelli Sea Attack T123',
        Priority = 310,
        InstanceCount = 20,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.NAVAL * (categories.TECH1 + categories.TECH2 + categories.TECH3) - categories.ENGINEER} },
            --{ SeaAttackCondition, { 'LocationType', 14 } },
        },
        BuilderData = {
            StateMachine = 'NavalZoneControl',
            SearchRadius = 'BaseEnemyArea',
            LocationType = 'LocationType',
            DistressRange = 180,
            UseFormation = 'None',
            AggressiveMove = false,
            ThreatSupport = 5,
            PlatoonLimit = 20,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.MASSFABRICATION,
                categories.ANTINAVY * categories.STRUCTURE,
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
        BuilderName = 'RNGAI Sea Hunters',
        PlatoonTemplate = 'RNGAI Sea Hunt',
        Priority = 310,
        PriorityFunction = SeaDefenseForm,
        InstanceCount = 20,
        BuilderType = 'Any',
        BuilderConditions = {
            -- Change to NUKESUB once the Cybran BP is updated
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.NAVAL * categories.ANTINAVY - categories.ENGINEER - categories.EXPERIMENTAL - categories.NUKE } },
            --{ SeaAttackCondition, { 'LocationType', 20 } },
        },
        BuilderData = {
            StateMachine = 'NavalCombat'
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
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MOBILE * categories.NAVAL * categories.SUBMERSIBLE * categories.TECH1 }},
            },
        BuilderData = {
            StateMachine = 'NavalZoneControl',
            MarkerType = 'Mass',            
            WaterOnly = true,
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            ThreatType = 'Economy',			    -- Type of threat to use for gauging attacks
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 140,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 50,			-- If threat is lower than this, do not attack
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
            StateMachine = 'NavalZoneControl',
            MarkerType = 'Mass',            
            FrigateRaid = true,
            WaterOnly = false,
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            ThreatType = 'Economy',			    -- Type of threat to use for gauging attacks
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 500,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 50,			-- If threat is lower than this, do not attack
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