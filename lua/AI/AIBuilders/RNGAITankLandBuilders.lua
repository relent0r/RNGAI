--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]

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
            { MIBC, 'FactionIndex', { 4, }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
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
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Tank 24',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 750, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.ENGINEER}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 24, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.05 }},
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Mortar 9',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 700,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatio', { 0.25, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE, '<=', categories.LAND * categories.DIRECTFIRE * categories.MOBILE}},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY LAND TECH3' }},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.05 }},
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Reaction Tanks',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'T1 Tank Enemy Nearby',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 850,
        BuilderConditions = {
            { TBC, 'EnemyThreatGreaterThanValueAtBase', { 'LocationType', 0, 'AntiSurface', 10 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 1.05 }},
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, categories.DIRECTFIRE * categories.LAND * categories.MOBILE } },
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
        Priority = 600,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatio', { 0.1, categories.LAND * categories.ANTIAIR, '<=', categories.LAND * categories.DIRECTFIRE}},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.LAND * categories.ANTIAIR } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 1.05 }},
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Anti Mass Small',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 900,                                                          -- Priority. 1000 is normal.
        InstanceCount = 4,                                                      -- Number of plattons that will be formed.
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = 120,                                               -- Searchradius for new target.
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = false,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MASSEXTRACTION + categories.ENGINEER, -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'MASSEXTRACTION',
                'ENGINEER',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Anti Mass Medium',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Medium',                          -- Template Name. These units will be formed. See: "UvesoPlatoonTemplatesLand.lua"
        Priority = 850,                                                          -- Priority. 1000 is normal.
        InstanceCount = 6,                                                      -- Number of plattons that will be formed.
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = 10000,                                               -- Searchradius for new target.
            GetTargetsFromBase = false,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchCategory = categories.MASSEXTRACTION + categories.ENGINEER, -- Only find targets matching these categories.
            PrioritizedCategories = {                                           -- Attack these targets.
                'MASSEXTRACTION',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Frequent Land Attack T1',
        PlatoonTemplate = 'LandAttackMedium',
        Priority = 100,
        InstanceCount = 12,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardBases = true,
            NeverGuardEngineers = true,
            UseFormation = 'AttackFormation',
        },        
        BuilderConditions = {
            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, categories.MOBILE * categories.LAND - categories.ENGINEER - categories.TECH1 } },
            { LandAttackCondition, { 'LocationType', 10 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI Unit Cap Default Land Attack',
        PlatoonTemplate = 'RNGAI LandAttack Medium',
        Priority = 100,
        InstanceCount = 10,
        BuilderType = 'Any',
        BuilderConditions = {
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
        BuilderName = 'RNGAI Start Location Attack',
        PlatoonTemplate = 'StartLocationAttack',
        Priority = 850,
        BuilderConditions = {     
        		{ MIBC, 'LessThanGameTime', { 720 } },  	
            },
        BuilderData = {
            MarkerType = 'Start Location',            
            MoveFirst = 'Closest',
            MoveNext = 'Guard Base',
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 100,
            AggressiveMove = true,      
            AvoidClosestRadius = 50,
            GuardTimer = 30,              
            UseFormation = 'AttackFormation',
        },    
        InstanceCount = 2,
        BuilderType = 'Any',
    }, 
    Builder {
        BuilderName = 'Base Location Guard Small',
        PlatoonTemplate = 'BaseGuardSmall',
        Priority = 800,
        BuilderConditions = { 
                #{ UCBC, 'ExpansionAreaNeedsEngineer', { 'LocationType', 350, -1000, 0, 2, 'StructuresNotMex' } },     
        		{ MIBC, 'LessThanGameTime', { 720 } },  	
                #{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.TECH2 * categories.MOBILE * categories.LAND - categories.ENGINEER } },
            },
        BuilderData = {
            LocationType = 'LocationType',
        },    
        InstanceCount = 2,
        BuilderType = 'Any',
    },
}