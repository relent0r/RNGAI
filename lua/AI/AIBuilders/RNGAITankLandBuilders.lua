--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

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
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { UCBC, 'LessThanGameTimeSeconds', { 240 } }, -- don't build after 4 minutes
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank 9',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 800, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { UCBC, 'LessThanGameTimeSeconds', { 360 } }, -- don't build after 6 minutes
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank 24',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 750, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 3, 'FACTORY TECH2, FACTORY TECH3' }}, -- stop building after we decent reach tech2 capability
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mortar 3',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 790,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.LAND * categories.MOBILE * categories.INDIRECTFIRE }},
            { UCBC, 'HaveUnitRatio', { 0.25, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE, '<=', categories.LAND * categories.DIRECTFIRE * categories.MOBILE}},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY LAND TECH3' }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mortar 9',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 750,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatio', { 0.25, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE, '<=', categories.LAND * categories.DIRECTFIRE * categories.MOBILE}},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY LAND TECH3' }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reaction Tanks',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Tank Enemy Nearby',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 1000,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 1, categories.MOBILE * categories.LAND - categories.SCOUT }}, -- threatRings value for 10km map should cover approx 100 radius
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.4, 0.6 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'MAIN', 2, categories.DIRECTFIRE * categories.LAND * categories.MOBILE } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land AA 2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Mobile AA',
        PlatoonTemplate = 'T1LandAA',
        Priority = 750,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatio', { 0.3, categories.LAND * categories.ANTIAIR, '<=', categories.LAND * categories.DIRECTFIRE}},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.LAND * categories.ANTIAIR } },
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
        BuilderName = 'RNGAI T2 Tank - Tech 2',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 750,
        BuilderType = 'Land',
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 MML',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 750,
        BuilderType = 'Land',
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.TECH2 * categories.FACTORY * categories.LAND }},
            { UCBC, 'HaveUnitRatio', { 0.30, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE, '<=', categories.LAND * categories.DIRECTFIRE * categories.MOBILE}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.0 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH3' }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Attack Tank - Tech 2',
        PlatoonTemplate = 'T2AttackTank',
        Priority = 750,
        BuilderType = 'Land',
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH3' }},
            { UCBC, 'HaveUnitRatio', { 0.3, categories.LAND * categories.TECH2 * categories.BOT, '<=', categories.LAND * categories.DIRECTFIRE * categories.TANK * categories.TECH2}},
            { MIBC, 'FactionIndex', { 1, 3}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.05 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile AA ',
        PlatoonTemplate = 'T2LandAA',
        Priority = 720,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'HaveUnitRatio', { 0.15, categories.LAND * categories.ANTIAIR, '<=', categories.LAND * categories.DIRECTFIRE}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Expansions',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Tank 24 Expansion',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 700, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY TECH2, FACTORY TECH3' }}, -- stop building after we decent reach tech2 capability
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mortar 9 Expansion',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 650,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatio', { 0.25, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE, '<=', categories.LAND * categories.DIRECTFIRE * categories.MOBILE}},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY LAND TECH3' }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mobile AA Expansion',
        PlatoonTemplate = 'T1LandAA',
        Priority = 650,
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.TECH2 * categories.LAND * categories.MOBILE * categories.ANTIAIR }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'HaveUnitRatio', { 0.1, categories.LAND * categories.ANTIAIR, '<=', categories.LAND * categories.DIRECTFIRE}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile AA Expansion',
        PlatoonTemplate = 'T2LandAA',
        Priority = 660,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'HaveUnitRatio', { 0.1, categories.LAND * categories.ANTIAIR, '<=', categories.LAND * categories.DIRECTFIRE}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.05 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 DF Tank - Tech 2 Expansion',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 700,
        BuilderType = 'Land',
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.05 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Attack Tank - Tech 2 Expansion',
        PlatoonTemplate = 'T2AttackTank',
        Priority = 700,
        BuilderType = 'Land',
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH3' }},
            { UCBC, 'HaveUnitRatio', { 0.30, categories.LAND * categories.TECH2 * categories.BOT, '<=', categories.LAND * categories.DIRECTFIRE * categories.TANK}},
            { MIBC, 'FactionIndex', { 1, 3}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.05 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 MML Expansion',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 750,
        BuilderType = 'Land',
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'HaveUnitRatio', { 0.30, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE, '<=', categories.LAND * categories.DIRECTFIRE * categories.MOBILE}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.05 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 1, categories.INDIRECTFIRE * categories.LAND } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY LAND TECH3' }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },

}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders Expansion',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1 Expansion',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 600,
        InstanceCount = 8,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
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
        BuilderName = 'RNGAI Unit Cap Default Land Attack Expansion',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 600,
        InstanceCount = 20,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND } },
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
        BuilderName = 'Frequent Land Attack T2 Expansion',
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
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.LAND * categories.TECH2 - categories.ENGINEER} },
            --{ LandAttackCondition, { 'LocationType', 50 } }, -- causing errors with expansions
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land Response Formers',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Response BaseRestrictedArea',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 1000,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE - categories.SCOUT }},
        },
        BuilderData = {
            SearchRadius = BaseRestrictedArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MOBILE * categories.LAND,         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'EXPERIMENTAL',
                'MOBILE LAND INDIRECTFIRE',
                'MOBILE LAND DIRECTFIRE',
                'STRUCTURE DEFENSE',
                'MOBILE LAND ANTIAIR',
                'STRUCTURE ANTIAIR',
                'ALLUNITS',
            },
            UseFormation = 'AttackFormation',
        },
    },
    Builder {
        BuilderName = 'RNGAI Response BaseMilitaryArea',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 900,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseMilitaryArea, 'LocationType', 0, categories.MOBILE - categories.SCOUT }},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            SearchRadius = BaseMilitaryArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MOBILE * categories.LAND,         -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'EXPERIMENTAL',
                'MOBILE LAND INDIRECTFIRE',
                'MOBILE LAND DIRECTFIRE',
                'STRUCTURE DEFENSE',
                'MOBILE LAND ANTIAIR',
                'STRUCTURE ANTIAIR',
                'ALLUNITS',
            },
            UseFormation = 'AttackFormation',
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Anti Mass Medium',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Medium',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 700,                                                          -- Priority. 1000 is normal.
        InstanceCount = 8,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'GrowthFormation',
            AggressiveMove = true,
        },
    },
    Builder {
        BuilderName = 'RNGAI Anti Mass Markers Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Large',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 700,                                                          -- Priority. 1000 is normal.
        InstanceCount = 8,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'GrowthFormation',
            AggressiveMove = true,
        },
    },
    Builder {
        BuilderName = 'RNGAI Ranged Attack',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 850,                                                          -- Priority. 1000 is normal.
        InstanceCount = 4,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'LessThanGameTimeSeconds', { 960 } }, -- don't build after 16 minutes
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE }},
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
        BuilderName = 'RNGAI Ranged Attack T2',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 850,                                                          -- Priority. 1000 is normal.
        InstanceCount = 4,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
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
        BuilderName = 'RNGAI Frequent Land Attack T1',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 100,
        InstanceCount = 12,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
            { UCBC, 'FactoryLessAtLocation', { 'MAIN', 3, 'FACTORY TECH2, FACTORY TECH3' }}, -- stop building after we decent reach tech2 capability
            --{ LandAttackCondition, { 'LocationType', 10 } }, -- causing errors with expansions
        },
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
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
        BuilderName = 'RNGAI Start Location Attack Early',
        PlatoonTemplate = 'RNGAI T1 Mass Hunters Category',
        Priority = 800,
        InstanceCount = 3,
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER} },  	
            },
        BuilderData = {
            MarkerType = 'Start Location',            
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 100,
            AggressiveMove = true,      
            AvoidClosestRadius = 50,
            GuardTimer = 15,              
            UseFormation = 'AttackFormation',
        },    
    }, 
    Builder {
        BuilderName = 'Frequent Land Attack T2',
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
    BuilderGroupName = 'RNGAI Land FormBuilders AntiMass',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Anti Mass Small',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI T1 Mass Hunters Category',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.TECH1 - categories.ENGINEER } },
        },
        BuilderData = {
            IgnoreFriendlyBase = true,
            MaxPathDistance = 1000, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            MarkerType = 'Mass',            
            MoveFirst = 'Random',
            MoveNext = 'Threat',
            ThreatType = 'Economy',			    -- Type of threat to use for gauging attacks
            FindHighestThreat = false,			-- Don't find high threat targets
            MaxThreatThreshold = 2900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 1000,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 75,
            AggressiveMove = false,      
            AvoidClosestRadius = 50,
            UseFormation = 'GrowthFormation',
            },
        },
        Builder {
            BuilderName = 'RNGAI Anti Mass Transport',                              -- This will be an attack squad with an engineer.
            PlatoonTemplate = 'RNGAI T1 Mass Hunters Transport',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
            Priority = 750,                                                          -- Priority. 1000 is normal.
            InstanceCount = 2,                                                      -- Number of platoons that will be formed.
            BuilderType = 'Any',
            BuilderConditions = {     
                { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND - categories.ENGINEER } },
            },
            BuilderData = {
                IgnoreFriendlyBase = true,
                MaxPathDistance = BaseDMZArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
                MarkerType = 'Mass',            
                MoveFirst = 'Random',
                MoveNext = 'Threat',
                ThreatType = 'Economy',			    -- Type of threat to use for gauging attacks
                FindHighestThreat = false,			-- Don't find high threat targets
                MaxThreatThreshold = 2900,			-- If threat is higher than this, do not attack
                MinThreatThreshold = 1000,		    -- If threat is lower than this, do not attack
                AvoidBases = true,
                AvoidBasesRadius = 75,
                AggressiveMove = true,      
                AvoidClosestRadius = 50,
                UseFormation = 'AttackFormation',
                },
        },
}