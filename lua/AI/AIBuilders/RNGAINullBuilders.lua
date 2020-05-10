local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Null TankLandBuilder',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Null Factory Land Attack',
        PlatoonTemplate = 'RNGAIT1LandAttackQueue',
        Priority = 750, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.01, 0.1}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, 'FACTORY LAND TECH2' }}, -- stop building after we decent reach tech2 capability

            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Null T2 Attack - Tech 2',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 760,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 4, 'FACTORY LAND TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Null T3 Attack - Tech 3',
        PlatoonTemplate = 'RNGAIT3LandAttackQueue',
        Priority = 770,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.6, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Null Land FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Null Spam Intelli',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 550,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            UseFormation = 'None',
            AggressiveMove = true,
            },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Null Response Formers',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Null Response BaseMilitary ANTIAIR Area',
        PlatoonTemplate = 'RNGAI Antiair Small',
        Priority = 1000,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseMilitaryArea, 'LocationType', 0, categories.MOBILE * categories.AIR * (categories.ANTIAIR + categories.BOMBER + categories.GROUNDATTACK) - categories.SCOUT }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.ANTIAIR - categories.INDIRECTFIRE} },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,
            GetTargetsFromBase = true,
            RequireTransport = false,
            AggressiveMove = true,
            LocationType = 'LocationType',
            Defensive = true,
            AttackEnemyStrength = 200,                              
            TargetSearchCategory = categories.MOBILE * categories.AIR - categories.SCOUT - categories.WALL ,
            PrioritizedCategories = {   
                'MOBILE AIR GROUNDATTACK',
                'MOBILE AIR BOMBER',
                'MOBILE AIR',
            },
            UseFormation = 'None',
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack MassRaid',
        PlatoonTemplate = 'RNGAI BomberAttack',
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 900,
        InstanceCount = 1,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            AvoidBases = true,
            SearchRadius = BaseEnemyArea,
            PrioritizedCategories = {
                'MASSEXTRACTION',
                'ENGINEER',
            },
        },
    },
}

