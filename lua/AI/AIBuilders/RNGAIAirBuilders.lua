--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIFighterAirBuilders.lua
    Author  :   relentless
    Summary :
        Air Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local AntiAirUnits = categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.ANTIAIR - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL - categories.GROUNDATTACK

local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

local AirDefenseMode = function(self, aiBrain, builderManager, builderData)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir
    local enemyCount = 1
    if aiBrain.EnemyIntel.EnemyCount > 0 then
        enemyCount = aiBrain.EnemyIntel.EnemyCount
    end
    if myAirThreat < (enemyAirThreat * 1.3 / enemyCount) then
        --RNGLOG('Enable Air Intie Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        if builderData.BuilderData.TechLevel == 1 then
            return 880
        elseif builderData.BuilderData.TechLevel == 2 then
            return 885
        elseif builderData.BuilderData.TechLevel == 3 then
            return 890
        end
        return 890
    else
        --RNGLOG('Disable Air Intie Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

local AirDefenseScramble = function(self, aiBrain, builderManager, builderData)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
    local enemyCount = 1
    if aiBrain.EnemyIntel.EnemyCount > 0 then
        enemyCount = aiBrain.EnemyIntel.EnemyCount
    end
    if math.max(myAirThreat, 15) < (enemyAirThreat / enemyCount) then
        --RNGLOG('Enable Air ASF Scramble Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        if builderData.BuilderData.TechLevel == 1 then
            return 880
        elseif builderData.BuilderData.TechLevel == 2 then
            return 885
        elseif builderData.BuilderData.TechLevel == 3 then
            return 890
        end
        return 870
    else
        --RNGLOG('Disable Air ASF Scramble Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

local AirAttackMode = function(self, aiBrain, builderManager, builderData)
    local myAirThreat = aiBrain.BrainIntel.SelfThreat.AirNow
    local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
    local enemyCount = 1
    if aiBrain.EnemyIntel.EnemyCount > 0 then
        enemyCount = aiBrain.EnemyIntel.EnemyCount
    end
    if aiBrain.BrainIntel.SelfThreat.AntiAirNow > 30 and myAirThreat / 1.3 > (enemyAirThreat / enemyCount) then
        --RNGLOG('Enable Air Attack Queue')
        aiBrain.BrainIntel.AirAttackMode = true
        if builderData.BuilderData.TechLevel == 1 then
            return 870
        elseif builderData.BuilderData.TechLevel == 2 then
            return 875
        elseif builderData.BuilderData.TechLevel == 3 then
            return 880
        end
        return 880
    else
        --RNGLOG('Disable Air Attack Queue')
        aiBrain.BrainIntel.AirAttackMode = false
        return 0
    end
end

local SeaTorpMode = function(self, aiBrain, builderManager, builderData)
    local myNavalThreat = aiBrain.BrainIntel.SelfThreat.NavalNow
    local enemyNavalThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Naval
    if myNavalThreat < enemyNavalThreat then
        --RNGLOG('Enable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 870
    else
        --RNGLOG('Disable Sub Pool Builder')
        --RNGLOG('My Sub Threat '..mySubThreat..'Enemy Sub Threat '..enemySubThreat)
        return 0
    end
end

local BomberResponse = function(self, aiBrain, builderManager, builderData)
    --RNGLOG('BomberResponse location is '..builderManager.LocationType)
    if aiBrain.BrainIntel.AirPhase < 2 and aiBrain.EnemyIntel.EnemyThreatCurrent.Air < aiBrain.BrainIntel.SelfThreat.AntiAirNow then
        --RNGLOG('Bomber Response for land phase < 2 and enemy air threat low')
        return 890
    end
    if aiBrain.BasePerimeterMonitor[builderManager.LocationType].LandUnits > 0 and aiBrain.BasePerimeterMonitor[builderManager.LocationType].AirUnits < 3 then
        --RNGLOG('Bomber Response for Perimeter Monitor is true')
        return 920
    end
    if aiBrain.CDRUnit.SuicideMode then
        return 920
    end
    return 0
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T1',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Intie Response',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 900,
        BuilderConditions = { 
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie Enemy Threat',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 0,
        PriorityFunction = AirDefenseMode,
        BuilderConditions = { 
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 1
        },
    },
    --[[Builder {
        BuilderName = 'RNGAI Factory Gunship T1',
        PlatoonTemplate = 'T1Gunship',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * (categories.TECH2 + categories.TECH3) }},
        },
        BuilderType = 'Air',
    },]]
    Builder {	
        BuilderName = 'RNGAI Factory Bomber T1 Response',	
        PlatoonTemplate = 'T1AirBomber',	
        Priority = 890,	
        PriorityFunction = BomberResponse,
        BuilderConditions = {	
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.7 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.0, 0.5}},	
        },	
        BuilderType = 'Air',	
        BuilderData = {
            LocationType = 'LocationType',
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T2',
    BuildersType = 'FactoryBuilder',
    --[[
    Builder {
        BuilderName = 'RNGAI Air Attack Queue T2',
        PlatoonTemplate = 'RNGAIT2AirQueue',
        Priority = 0,
        PriorityFunction = AirAttackMode,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * categories.TECH3 }},
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },]]
    Builder {
        BuilderName = 'RNGAI Factory Intie Enemy Threat T2',
        PlatoonTemplate = 'RNGAIT2FighterAeon',
        Priority = 0,
        PriorityFunction = AirDefenseMode,
        BuilderConditions = { 
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI Factory Swift Wind Response',
        PlatoonTemplate = 'RNGAIT2FighterAeon',
        Priority = 910,
        BuilderConditions = { 
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
        },
        BuilderType = 'Air',
    },
    --[[Builder {
        BuilderName = 'RNGAI Factory T2 FighterBomber ACUClose',
        PlatoonTemplate = 'T2FighterBomber',
        Priority = 800,
        BuilderType = 'Air',
        BuilderConditions = { 
            { TBC, 'EnemyACUCloseToBase', {}},
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Gunship',
        PlatoonTemplate = 'T2AirGunship',
        Priority = 700,
        BuilderType = 'Air',
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 12, categories.AIR * categories.GROUNDATTACK * categories.TECH2} },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.AIR * categories.TECH3 }},
        },
    },]]
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T3',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory ASF Response',
        PlatoonTemplate = 'T3AirFighter',
        Priority = 900,
        BuilderConditions = { 
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.7 }},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory ASF Scramble',
        PlatoonTemplate = 'T3AirFighter',
        Priority = 0,
        PriorityFunction = AirDefenseScramble,
        BuilderConditions = { 
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.7 }},
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Air Attack Queue',
        PlatoonTemplate = 'RNGAIT3AirAttackQueue',
        Priority = 0,
        PriorityFunction = AirAttackMode,
        BuilderType = 'Air',
        BuilderConditions = {
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.AIR * categories.TECH3 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.85 }},
        },
        BuilderData = {
            TechLevel = 3
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Response Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Air Mercy BaseEnemyArea',
        PlatoonTemplate = 'RNGAI MercyAttack',
        Priority = 960,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderData = {
            PlatoonPlan = 'MercyAIRNG',
            Location = 'LocationType',
            SearchRadius = BaseEnemyArea,
            PrioritizedCategories = {
                categories.COMMAND,
                categories.LAND * categories.EXPERIMENTAL,
            },
        },
        BuilderConditions = {
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.daa0206 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI Air AntiNavy BaseEnemyArea',
        PlatoonTemplate = 'RNGAI TorpBomberAttack',
        Priority = 960,
        InstanceCount = 4,
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            UnitType = 'TORPEDO',
            PrioritizedCategories = {
                categories.COMMAND,
                categories.EXPERIMENTAL,
                categories.NAVAL * categories.TECH3 * (categories.MOBILE + categories.STRUCTURE ),
                categories.NAVAL * categories.TECH2 * (categories.MOBILE + categories.STRUCTURE ),
                categories.DEFENSE * categories.ANTIAIR,
                categories.NAVAL * categories.TECH1 * (categories.MOBILE + categories.STRUCTURE ),
                categories.STRUCTURE * categories.SONAR,
                categories.AMPHIBIOUS - categories.HOVER,
            },
        },
        BuilderConditions = {
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.ANTINAVY - categories.EXPERIMENTAL } },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Platoon Builder',
    BuildersType = 'PlatoonFormBuilder', -- A PlatoonFormBuilder is for builder groups of units.
    Builder {
        BuilderName = 'RNGAI Air Intercept',
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 800,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderData = {
            AvoidBases = true,
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            NeverGuardEngineers = true,
            PlatoonLimit = 25,
            PrioritizedCategories = {
                categories.EXPERIMENTAL * categories.AIR,
                categories.GROUNDATTACK * categories.AIR,
                categories.BOMBER * categories.AIR,
                categories.ANTIAIR * categories.AIR,
            },
        },
        BuilderConditions = {
            --{ UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'ANTIAIR', categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.ANTIAIR - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL - categories.GROUNDATTACK } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, AntiAirUnits } },
         },
    },
    Builder {
        BuilderName = 'RNGAI Air Feeder',
        PlatoonTemplate = 'RNGAI AntiAirFeeder',
        Priority = 750,
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        InstanceCount = 30,
        BuilderType = 'Any',
        BuilderData = {
            PlatoonType = 'fighter',
            PlatoonSearchRange = BaseDMZArea,
            AvoidBases = true,
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            NeverGuardEngineers = true,
            PlatoonLimit = 18,
            PrioritizedCategories = {
                categories.EXPERIMENTAL * categories.AIR,
                categories.GROUNDATTACK * categories.AIR,
                categories.BOMBER * categories.AIR,
                categories.ANTIAIR * categories.AIR,
            },
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, AntiAirUnits } },
         },
    },
    Builder {
        BuilderName = 'RNGAI Air Lockdown',
        PlatoonTemplate = 'RNGAI AntiAirLockdown',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 750,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
            PrioritizedCategories = {
                categories.EXPERIMENTAL * categories.AIR,
                categories.BOMBER * categories.AIR,
                categories.GROUNDATTACK * categories.AIR,
                categories.ANTIAIR * categories.AIR,
            },
        },
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'ANTIAIR', AntiAirUnits } },
         },
    },
    Builder {
        BuilderName = 'RNGAI Bomber T1 Attack Engineers',
        PlatoonTemplate = 'RNGAI BomberAttack T1',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 905,
        InstanceCount = 3,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER * categories.TECH1 } },
        },
        BuilderData = {
            StaticCategories = true,
            AvoidBases = true,
            IgnoreCivilian = true,
            SearchRadius = BaseEnemyArea,
            UnitType = 'BOMBER',
            UnitTarget = 'ENGINEER',
            LocationType = 'LocationType',
            PlatoonLimit = 2,
            PrioritizedCategories = {
                categories.ENGINEER - categories.COMMAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.DEFENSE,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber T1 Attack Defense',
        PlatoonTemplate = 'RNGAI BomberAttack T1',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 910,
        InstanceCount = 10,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { TBC, 'LandThreatAtBaseOwnZones', { }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER * categories.TECH1 } },
        },
        BuilderData = {
            Defensive = true,
            StaticCategories = true,
            AvoidBases = true,
            IgnoreCivilian = true,
            SearchRadius = BaseMilitaryArea,
            UnitType = 'BOMBER',
            PlatoonLimit = 3,
            PrioritizedCategories = {
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER - categories.COMMAND,
                categories.MASSEXTRACTION * categories.TECH1,
                categories.STRUCTURE * categories.RADAR,
                categories.STRUCTURE * categories.ENERGYSTORAGE,
                categories.STRUCTURE,
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack MassRaid',
        PlatoonTemplate = 'RNGAI BomberAttack',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 900,
        InstanceCount = 2,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            AvoidBases = true,
            Defensive = false,
            SearchRadius = BaseEnemyArea,
            UnitType = 'BOMBER',
            IgnoreCivilian = true,
            PlatoonLimit = 5,
            PrioritizedCategories = {
                categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                categories.MASSEXTRACTION,
                categories.ENGINEER * categories.TECH2,
                categories.ENGINEER * categories.TECH3,
                categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3),
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
                categories.NAVAL * categories.CRUISER,
                categories.NAVAL - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Gunship Attack T1',
        PlatoonTemplate = 'RNGAI GunShipAttack',
        Priority = 890,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = { 
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.MOBILE * categories.GROUNDATTACK * categories.TECH1 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            AvoidBases = true,
            UnitType = 'GUNSHIP',
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Gunship Attack T2T3',
        PlatoonTemplate = 'RNGAI GunShipAttack',
        Priority = 890,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.MOBILE * categories.GROUNDATTACK * (categories.TECH2 + categories.TECH3) } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            UnitType = 'GUNSHIP',
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.MOBILE * categories.LAND,
                categories.MASSEXTRACTION,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ALLUNITS - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack Enemy',
        PlatoonTemplate = 'RNGAI BomberAttack',
        Priority = 890,
        InstanceCount = 2,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            IgnoreCivilian = true,
            UnitType = 'BOMBER',
            PlatoonLimit = 18,
            PrioritizedCategories = {
                categories.RADAR * categories.STRUCTURE,
                categories.ENGINEER * categories.TECH1,
                categories.MOBILE * categories.ANTIAIR,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.SUBCOMMANDER,
                categories.MOBILE * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
                categories.NAVAL - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack Excess',
        PlatoonTemplate = 'RNGAI BomberAttack',
        Priority = 700,
        InstanceCount = 20,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'BOMBER', categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            UnitType = 'BOMBER',
            PlatoonLimit = 18,
            PrioritizedCategories = {
       --         categories.TECH3 * categories.ANTIMISSILE * categories.SILO * categories.STRUCTURE,
                categories.TECH3 * categories.NUKE * categories.SILO * categories.STRUCTURE,
                categories.TECH3 * categories.ARTILLERY * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.SUBCOMMANDER,
                categories.MASSEXTRACTION,
                categories.ENGINEER * categories.MOBILE,
                categories.MOBILE * categories.ANTIAIR,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
                categories.NAVAL - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
            DistressRange = 130,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TransportFactoryBuilders Large',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Large NoPath',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 950,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 11.0 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.80, 0.80 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Large',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 900,
        BuilderConditions = {
            { MIBC, 'ArmyNeedOrWantTransports', {} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.TRANSPORTFOCUS * categories.TECH1 - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 1.1 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Excess Large',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 890,
        BuilderConditions = {
            { MIBC, 'ArmyNeedOrWantTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.8}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport Large',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 910,
        BuilderConditions = {
            { MIBC, 'ArmyNeedOrWantTransports', {} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.TRANSPORTFOCUS * categories.TECH2 - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.05 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport Excess Large',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 900,
        BuilderConditions = {
            { MIBC, 'ArmyNeedOrWantTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.8}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.TRANSPORTFOCUS * categories.TECH2 - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TransportFactoryBuilders Small',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Transport NoPath',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 880,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND', true } },
            { MIBC, 'ArmyNeedOrWantTransports', {} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 0.95 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 880,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 0.95 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Transport Excess',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'MapGreaterThan', { 256, 256 }},
            { MIBC, 'ArmyNeedOrWantTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.8}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 860,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.TRANSPORTFOCUS * categories.TECH2 - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.85, 1.05 }},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Air Transport Excess',
        PlatoonTemplate = 'T2AirTransport',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'MapGreaterThan', { 256, 256 }},
            { MIBC, 'ArmyNeedOrWantTransports', {} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.8}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.TRANSPORTFOCUS * categories.TECH2 - categories.GROUNDATTACK } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.TRANSPORTFOCUS - categories.GROUNDATTACK } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1 }},
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP Air Platoon Builder',
    BuildersType = 'PlatoonFormBuilder', -- A PlatoonFormBuilder is for builder groups of units.
    Builder {
        BuilderName = 'RNGEXP Air Intercept',
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 800,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderData = {
            AvoidBases = true,
            NeverGuardEngineers = true,
            PlatoonLimit = 25,
            PrioritizedCategories = {
                categories.EXPERIMENTAL * categories.AIR,
                categories.GROUNDATTACK * categories.AIR,
                categories.BOMBER * categories.AIR,
                categories.ANTIAIR * categories.AIR,
            },
        },
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'ANTIAIR', AntiAirUnits } },
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.ANTIAIR - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL - categories.GROUNDATTACK } },
         },
    },
    Builder {
        BuilderName = 'RNGEXP Air Feeder',
        PlatoonTemplate = 'RNGAI AntiAirFeeder',
        Priority = 750,
        InstanceCount = 30,
        BuilderType = 'Any',
        BuilderData = {
            PlatoonType = 'fighter',
            PlatoonSearchRange = BaseDMZArea,
            AvoidBases = true,
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            NeverGuardEngineers = true,
            PlatoonLimit = 18,
            PrioritizedCategories = {
                categories.EXPERIMENTAL * categories.AIR,
                categories.GROUNDATTACK * categories.AIR,
                categories.BOMBER * categories.AIR,
                categories.ANTIAIR * categories.AIR,
            },
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, AntiAirUnits } },
         },
    },
    Builder {
        BuilderName = 'RNGEXP Air Lockdown',
        PlatoonTemplate = 'RNGAI AntiAirLockdown',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 750,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
            PrioritizedCategories = {
                categories.EXPERIMENTAL * categories.AIR,
                categories.BOMBER * categories.AIR,
                categories.GROUNDATTACK * categories.AIR,
                categories.ANTIAIR * categories.AIR,
            },
        },
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'ANTIAIR', AntiAirUnits } },
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
         },
    },
    Builder {
        BuilderName = 'RNGEXP Bomber Attack MassRaid',
        PlatoonTemplate = 'RNGAI BomberAttack',
        PlatoonAddBehaviors = { 'AirUnitRefitRNG' },
        Priority = 900,
        InstanceCount = 2,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            AvoidBases = true,
            SearchRadius = BaseEnemyArea,
            UnitType = 'BOMBER',
            PlatoonLimit = 18,
            PrioritizedCategories = {
                categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                categories.MASSEXTRACTION,
                categories.ENGINEER * categories.TECH2,
                categories.ENGINEER * categories.TECH3,
                categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3),
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
                categories.NAVAL * categories.CRUISER,
                categories.NAVAL - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGEXP Gunship Attack T1',
        PlatoonTemplate = 'RNGAI GunShipAttack',
        Priority = 890,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = { 
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.AIR * categories.MOBILE * categories.GROUNDATTACK * categories.TECH1 } },
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            AvoidBases = true,
            UnitType = 'GUNSHIP',
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.MASSEXTRACTION,
                categories.ALLUNITS - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGEXP Gunship Attack T2T3',
        PlatoonTemplate = 'RNGAI GunShipAttack',
        Priority = 890,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = { 
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'AIR', categories.AIR * categories.MOBILE * categories.GROUNDATTACK * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 - categories.SUPPORTFACTORY }},
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            UnitType = 'GUNSHIP',
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.MOBILE * categories.LAND,
                categories.MASSEXTRACTION,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ALLUNITS,
            },
            PrioritizedCategories = {
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.ALLUNITS - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGEXP Bomber Attack Enemy',
        PlatoonTemplate = 'RNGAI BomberAttack',
        Priority = 890,
        InstanceCount = 3,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'BOMBER', categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            IgnoreCivilian = true,
            UnitType = 'BOMBER',
            PlatoonLimit = 18,
            PrioritizedCategories = {
                categories.RADAR * categories.STRUCTURE,
                categories.ENGINEER * categories.TECH1,
                categories.MOBILE * categories.ANTIAIR,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.MOBILE * categories.LAND,
                categories.MASSEXTRACTION,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
                categories.NAVAL - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
        },
    },
    Builder {
        BuilderName = 'RNGEXP Bomber Attack Excess',
        PlatoonTemplate = 'RNGAI BomberAttack',
        Priority = 700,
        InstanceCount = 20,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'BOMBER', categories.MOBILE * categories.AIR * categories.BOMBER - categories.daa0206 } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            UnitType = 'BOMBER',
            PlatoonLimit = 18,
            PrioritizedCategories = {
       --         categories.TECH3 * categories.ANTIMISSILE * categories.SILO * categories.STRUCTURE,
                categories.TECH3 * categories.NUKE * categories.SILO * categories.STRUCTURE,
                categories.TECH3 * categories.ARTILLERY * categories.STRUCTURE,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
                categories.MASSEXTRACTION,
                categories.ENGINEER * categories.MOBILE,
                categories.MOBILE * categories.ANTIAIR,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
                categories.NAVAL - (categories.T1SUBMARINE + categories.T2SUBMARINE),
            },
            DistressRange = 130,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    },
}