--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
RNGLOG('* AI-RNG: BaseRestricted :'..BaseRestrictedArea..' BaseMilitary :'..BaseMilitaryArea..' BaseDMZArea :'..BaseDMZArea..' BaseEnemy :'..BaseEnemyArea)
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'

local LandAttackHeavyMode = function(self, aiBrain, builderManager, builderData)
    local myExtractorCount = aiBrain.BrainIntel.SelfThreat.AllyExtratorCount
    local totalMassMarkers = aiBrain.BrainIntel.SelfThreat.MassMarker
    if myExtractorCount > totalMassMarkers / 2 then
        --RNGLOG('Enable Land Heavy Attack Queue')
        if builderData.TechLevel == 1 then
            return 780
        elseif builderData.TechLevel == 2 then
            return 785
        elseif builderData.TechLevel == 3 then
            return 790
        end
        return 790
    else
        --RNGLOG('Disable Land Heavy Attack Queue')
        return 0
    end
end

local LandAttackMode = function(self, aiBrain, builderManager, builderData)
    local myExtractorCount = aiBrain.BrainIntel.SelfThreat.AllyExtratorCount
    local totalMassMarkers = aiBrain.BrainIntel.SelfThreat.MassMarker
    if myExtractorCount < totalMassMarkers / 2 then
        --RNGLOG('Enable Land Attack Queue')
        if builderData.TechLevel == 1 then
            return 780
        elseif builderData.TechLevel == 2 then
            return 785
        elseif builderData.TechLevel == 3 then
            return 790
        end
        return 790
    else
        --RNGLOG('Disable Land Attack Queue')
        return 0
    end
end

local LandEngMode = function(self, aiBrain, builderManager, builderData)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits <= 4 then
        --RNGLOG('Setting T1 Queue to Eng')
        if builderData.TechLevel == 1 then
            return 745
        elseif builderData.TechLevel == 2 then
            return 750
        elseif builderData.TechLevel == 3 then
            return 755
        end
        return 750
    else
        return 0
    end
end

local LandNoEngMode = function(self, aiBrain, builderManager, builderData)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits > 4 then
        --RNGLOG('Setting T1 Queue to NoEng')
        if builderData.TechLevel == 1 then
            return 745
        elseif builderData.TechLevel == 2 then
            return 750
        elseif builderData.TechLevel == 3 then
            return 755
        end
        return 750
    else
        return 0
    end
end

local AmphibSiegeMode = function(self, aiBrain, builderManager)
    local locationType = builderManager.LocationType
    --RNGLOG('Builder Mananger location type is '..locationType)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits <= 3 then
        --RNGLOG('Setting Amphib Siege Mode')
        return 550
    else
        return 0
    end
end

local AmphibNoSiegeMode = function(self, aiBrain, builderManager)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits >= 3 then
        --RNGLOG('Setting Amphib Non Siege Mode')
        return 550
    else
        return 0
    end
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
        BuilderName = 'RNGAI Factory Initial Queue 10km Small',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild10k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 1000 } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 120 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Initial Queue 5km Small',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild5k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 500 } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 120 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Small',
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueue',
        Priority = 500, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory T3 Amphib Attack Small',
        PlatoonTemplate = 'RNGAIT3AmphibAttackQueue',
        Priority = 550, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Large',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Initial Queue 20km',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild20k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 2000 } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 240 } }, 
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Factory Initial Queue 40km',
        PlatoonTemplate = 'RNGAIT1InitialAttackBuild20k',
        Priority = 820, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 4000 } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 270 } }, 
            { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    --[[Builder {
        BuilderName = 'RNGAI Factory Land Attack Large',
        PlatoonTemplate = 'RNGAIT1LandAttackQueue',
        Priority = 750, -- After Second Engie Group
        PriorityFunction = LandEngMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 7, categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI Factory Land Attack NoEng Large',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueNoEng',
        Priority = 0, -- After Second Engie Group
        PriorityFunction = LandNoEngMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 7, categories.FACTORY * categories.LAND * ( categories.TECH2 + categories.TECH3 ) }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Attack Large',
        PlatoonTemplate = 'RNGAIT2LandAttackQueue',
        Priority = 760,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },]]
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Large',
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueue',
        Priority = 0,
        PriorityFunction = AmphibNoSiegeMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50, 'LAND'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI Factory Amphib Attack Large Siege',
        PlatoonTemplate = 'RNGAIT2AmphibAttackQueueSiege',
        Priority = 0,
        PriorityFunction = AmphibSiegeMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50, 'LAND'}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 5, categories.FACTORY * categories.LAND * categories.TECH3 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
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
        Priority = 0,
        PriorityFunction = AmphibNoSiegeMode,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI Factory T3 Amphib Attack Large Siege',
        PlatoonTemplate = 'RNGAIT3AmphibAttackQueueSiege',
        Priority = 0,
        PriorityFunction = AmphibSiegeMode,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
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
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
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
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
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
    --[[Builder {
        BuilderName = 'RNGAI Attack T3 Small',
        PlatoonTemplate = 'RNGAIT3LandAttackQueue',
        Priority = 790,
        PriorityFunction = LandAttackMode,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI Attack Heavy T3 Small',
        PlatoonTemplate = 'RNGAIT3LandAttackQueueHeavy',
        Priority = 0,
        PriorityFunction = LandAttackHeavyMode,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },]]
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
    --[[Builder {
        BuilderName = 'RNGAI Attack T3 Large',
        PlatoonTemplate = 'RNGAIT3LandAttackQueue',
        Priority = 770,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI Attack Heavy T3 Large',
        PlatoonTemplate = 'RNGAIT3LandAttackQueueHeavy',
        Priority = 0,
        PriorityFunction = LandAttackHeavyMode,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.80 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.50}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },]]
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
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE - categories.ENGINEER }},
            { MIBC, 'FactionIndex', { 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
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
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE - categories.ENGINEER }},
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
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 1.0 }},
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
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TankLandBuilder Small Expansions',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Land Expansion Sml',
        PlatoonTemplate = 'RNGAIT1LandAttackQueueExp',
        Priority = 700, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }}, -- stop building after we decent reach tech2 capability
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.5, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T2 Land Expansion Sml',
        PlatoonTemplate = 'RNGAIT2LandAttackQueueExp',
        Priority = 700,
        BuilderType = 'Land',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
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
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
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
        PlatoonTemplate = 'RNGAI T1 Zone Raiders Small',                          -- Template Name.
        Priority = 600,                                                          -- Priority. 1000 is normal.
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND - categories.ENGINEER } },
        },
        BuilderData = {
            Avoid        = true,
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            LocationType = 'LocationType',
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
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
                categories.ENERGYPRODUCTION,
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
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
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
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Common Expansion Quick Small',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 5,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.ENERGYPRODUCTION,
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
            ThreatSupport = 0,
        },
    },
    Builder {
        BuilderName = 'RNGAI Spam Aeon Expansion',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon Intelli',                          -- Template Name. 
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.ENERGYPRODUCTION,
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
            ThreatSupport = 0,
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
        PlatoonTemplate = 'RNGAI T1 Zone Raiders Small',                          -- Template Name.
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            LocationType = 'LocationType',
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
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
                categories.ENERGYPRODUCTION,
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
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
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
    Builder {
        BuilderName = 'RNGAI Spam Aeon Expansion Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon Intelli',                          -- Template Name. 
        Priority = 650,                                                          -- Priority. 1000 is normal.
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
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
    Builder {
        BuilderName = 'RNGAI Response BaseRestrictedArea',                              -- Random Builder Name.
        PlatoonTemplate = 'RNG TruePlatoon Combat',                          -- Template Name. 
        PlatoonAddBehaviors = { 'ZoneUpdate' },
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
            SearchRadius = BaseEnemyArea,
            --[[SearchRadius = BaseMilitaryArea,                                               -- Searchradius for new target.
            DistressRange = BaseMilitaryArea,
            GetTargetsFromBase = true,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            LocationType = 'LocationType',
            Defensive = true,
            PlatoonLimit = 12,
            AttackEnemyStrength = 100,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            TargetSearchPriorities = {
                categories.EXPERIMENTAL,
                categories.MOBILE *categories.LAND,
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.EXPERIMENTAL,
                categories.MOBILE * categories.LAND * categories.INDIRECTFIRE,
                categories.MOBILE * categories.LAND * categories.DIRECTFIRE,
                categories.ENGINEER,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND * categories.ANTIAIR,
                categories.STRUCTURE * categories.ANTIAIR,
                categories.ALLUNITS - categories.AIR - categories.NAVAL,
            },
            UseFormation = 'None',
            ThreatSupport = 1,]]
        },
    },
    Builder {
        BuilderName = 'RNGAI Response BaseMilitary ANTIAIR Area',
        PlatoonTemplate = 'RNGAI Antiair Small',
        Priority = 1000,
        InstanceCount = 3,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
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
            TargetSearchPriorities = { 
                categories.EXPERIMENTAL * categories.AIR,
                categories.MOBILE * categories.AIR
            },
            PrioritizedCategories = {   
                categories.EXPERIMENTAL * categories.AIR,
                categories.MOBILE * categories.AIR * categories.GROUNDATTACK,
                categories.MOBILE * categories.AIR * categories.BOMBER,
                categories.MOBILE * categories.AIR,
            },
            UseFormation = 'None',
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Land FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNGAI Start Location Attack',
        PlatoonTemplate = 'RNGAI Guard Marker Small',
        Priority = 700,
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderConditions = {     
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER} },
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER} },  	
            },
        BuilderData = {
            MarkerType = 'Start Location',            
            SafeZone = true,
            MoveFirst = 'Threat',
            LocationType = 'LocationType',
            MoveNext = 'Threat',
            IgnoreFriendlyBase = true,
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 30,
            AggressiveMove = false,      
            AvoidClosestRadius = 50,
            GuardTimer = 10,              
            UseFormation = 'AttackFormation',
            ThreatType = 'Structures',
            PrioritizedCategories = {
                categories.COMMAND,
                categories.MASSEXTRACTION,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        }, 
    },
    Builder {
        BuilderName = 'RNGAI Zone Control',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI Zone Control',                          -- Template Name. 
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        BuilderType = 'Any',
        BuilderConditions = {
            --{ UCBC, 'LessThanGameTimeSecondsRNG', { 300 } }, -- don't build after 5 minutes
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
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
        PlatoonTemplate = 'RNG TruePlatoon Combat',                          -- Template Name. 
        Priority = 700,                                                          -- Priority. 1000 is normal.
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        InstanceCount = 4,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            },
    },
    
    Builder {
        BuilderName = 'RNGAI Spam Intelli',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'PlatoonRetreat' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
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
        BuilderName = 'RNGAI Spam Intelli Amphib',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Amphib',                          -- Template Name. 
        Priority = 710,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * ( categories.AMPHIBIOUS + categories.HOVER ) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            TargetSearchPriorities = {
                categories.ENERGYPRODUCTION,
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
        --PlatoonAddBehaviors = { 'PlatoonRetreat' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            --{ UCBC, 'PoolGreaterAtLocation', { 'LocationType', 6, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
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
        BuilderName = 'RNGAI Spam Aeon',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.DIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
            },
    }, 
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 10,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
        },
        BuilderData = {
            RangedAttack = true,
            SearchRadius = BaseEnemyArea,                                               -- Searchradius for new target.
            GetTargetsFromBase = false,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.STRUCTURE * categories.DEFENSE,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
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
        BuilderName = 'RNGAI Start Location Attack Large',
        PlatoonTemplate = 'RNGAI Guard Marker Small',
        Priority = 700,
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 3,
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER} },  	
            },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            MarkerType = 'Start Location',            
            MoveFirst = 'Threat',
            SafeZone = true,
            MoveNext = 'Threat',
            IgnoreFriendlyBase = true,
            --ThreatType = '',
            --SelfThreat = '',
            --FindHighestThreat ='',
            --ThreatThreshold = '',
            AvoidBases = true,
            AvoidBasesRadius = 30,
            AggressiveMove = false,      
            AvoidClosestRadius = 50,
            GuardTimer = 10,              
            UseFormation = 'AttackFormation',
            ThreatSupport = 0,
            PrioritizedCategories = {
                categories.COMMAND,
                categories.MASSEXTRACTION,
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.MOBILE * categories.LAND,
                categories.ENGINEER,
            },
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },    
    },
    Builder {
        BuilderName = 'RNGAI Trueplatoon Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNG TruePlatoon Combat',                          -- Template Name. 
        Priority = 690,                                                          -- Priority. 1000 is normal.
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        InstanceCount = 4,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            },
    },
    Builder {
        BuilderName = 'RNGAI Spam Intelli Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'PlatoonRetreat' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 30,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            PlatoonLimit = 18,
            AggressiveMove = true,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENERGYPRODUCTION,
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
    Builder {
        BuilderName = 'RNGAI Spam Intelli Amphib Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Amphib',                          -- Template Name. 
        Priority = 710,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.MOBILE * categories.LAND * ( categories.AMPHIBIOUS + categories.HOVER ) - categories.ENGINEER - categories.EXPERIMENTAL}},
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            PlatoonLimit = 15,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENERGYPRODUCTION,
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
        BuilderName = 'RNGAI Spam Aeon Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Aeon',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 550,                                                          -- Priority. 1000 is normal.
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.DIRECTFIRE) - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
            DistressRange = 120,
            DistressReactionTime = 6,
            ThreatSupport = 0,
        },
    }, 
    Builder {
        BuilderName = 'RNGAI Ranged Attack T2 Large',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Small Ranged',                          -- Template Name. 
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        Priority = 800,                                                          -- Priority. 1000 is normal.
        InstanceCount = 10,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.LAND * categories.INDIRECTFIRE * categories.MOBILE * categories.TECH2}},
        },
        BuilderData = {
            RangedAttack = true,
            SearchRadius = BaseEnemyArea,                                               -- Searchradius for new target.
            LocationType = 'LocationType',
            GetTargetsFromBase = false,                                         -- Get targets from base position (true) or platoon position (false)
            RequireTransport = false,                                           -- If this is true, the unit is forced to use a transport, even if it has a valid path to the destination.
            AggressiveMove = true,                                              -- If true, the unit will attack everything while moving to the target.
            AttackEnemyStrength = 200,                                          -- Compare platoon to enemy strenght. 100 will attack equal, 50 weaker and 150 stronger enemies.
            LocationType = 'LocationType',
            TargetSearchPriorities = {
                categories.STRUCTURE,
                categories.MOBILE * categories.LAND,
            },
            PrioritizedCategories = {                                           -- Attack these targets.
                categories.STRUCTURE * categories.DEFENSE,
                categories.MASSEXTRACTION,
                categories.ENERGYPRODUCTION,
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
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Hover',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 4 }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.INDIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            ThreatSupport = 0,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENERGYPRODUCTION,
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
    Builder {
        BuilderName = 'RNGAI Aeon Tanks Island',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGAI LandAttack Spam Intelli Hover',                          -- Template Name. 
        Priority = 550,                                                          -- Priority. 1000 is normal.
        --PlatoonAddBehaviors = { 'TacticalResponse' },
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        InstanceCount = 20,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 4, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH1 - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            UseFormation = 'None',
            AggressiveMove = true,
            PlatoonLimit = 18,
            TargetSearchPriorities = {
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENERGYPRODUCTION,
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
        PlatoonTemplate = 'RNGAI T1 Zone Raiders Small',                          -- Template Name. 
        Priority = 700,                                                          -- Priority. 1000 is normal.
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        PriorityFunction = NoSmallFrys,
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 3, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            Avoid        = true,
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 650,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 50,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 150,
            AggressiveMove = false,      
            AvoidClosestRadius = 100,
            UseFormation = 'AttackFormation',
            TargetSearchPriorities = { 
                categories.MASSEXTRACTION,
                categories.MOBILE * categories.LAND
            },
            SetWeaponPriorities = true,
            PrioritizedCategories = {   
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.SCOUT,
                categories.ENERGYPRODUCTION,
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
        PlatoonTemplate = 'RNGAI Zone Raiders Medium',                          -- Template Name.
        PlatoonAddPlans = { 'DistressResponseAIRNG' },
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        Priority = 610,                                                          -- Priority. 1000 is normal.
        InstanceCount = 2,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 5, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.ENGINEER } },
        },
        BuilderData = {
            Avoid        = true,
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 8900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 50,		    -- If threat is lower than this, do not attack
            AvoidBases = true,
            AvoidBasesRadius = 120,
            AggressiveMove = false,      
            AvoidClosestRadius = 15,
            UseFormation = 'NoFormation',
            TargetSearchPriorities = { 
                categories.MASSEXTRACTION,
                categories.MOBILE * categories.LAND
            },
            SetWeaponPriorities = true,
            PrioritizedCategories = {   
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.SCOUT,
                categories.ENERGYPRODUCTION,
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
        PlatoonTemplate = 'RNGAI Zone Raiders Medium',                          -- Template Name.
        PlatoonAddBehaviors = { 'ZoneUpdate' },
        Priority = 600,                                                          -- Priority. 1000 is normal.
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {     
            { UCBC, 'ScalePlatoonSizeRNG', { 'LocationType', 'LAND', categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.ENGINEER} },  	
        },
        BuilderData = {
            SearchRadius = BaseEnemyArea,
            LocationType = 'LocationType',
            IncludeWater = false,
            IgnoreFriendlyBase = true,
            MaxPathDistance = BaseEnemyArea, -- custom property to set max distance before a transport will be requested only used by GuardMarker plan
            FindHighestThreat = true,			-- Don't find high threat targets
            MaxThreatThreshold = 9900,			-- If threat is higher than this, do not attack
            MinThreatThreshold = 100,		    -- If threat is lower than this, do not attack
            AvoidBases = false,
            AvoidBasesRadius = 150,
            AggressiveMove = true,      
            AvoidClosestRadius = 15,
            UseFormation = 'NoFormation',
            TargetSearchPriorities = { 
                categories.MASSEXTRACTION,
                categories.MOBILE * categories.LAND,
            },
            SetWeaponPriorities = true,
            PrioritizedCategories = {   
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.SCOUT,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.MOBILE * categories.LAND,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.ALLUNITS - categories.INSIGNIFICANTUNIT,
            },
            },
    },
}
