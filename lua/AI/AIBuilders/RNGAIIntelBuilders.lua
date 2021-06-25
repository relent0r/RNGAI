--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIIntelBuilders.lua
    Author  :   relentless
    Summary :
        Intel Builders
]]

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

local ActiveExpansion = function(self, aiBrain, builderManager)
    --LOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --LOG('Active Expansion is set'..builderManager.LocationType)
        --LOG('Active Expansion builders are set to 900')
        return 900
    else
        --LOG('Disable Air Intie Pool Builder')
        --LOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarBuilders',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Radar T1',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, (categories.RADAR + categories.OMNI) * categories.STRUCTURE}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION,
                AdjacencyDistance = 70,
                BuildClose = false,
                BuildStructures = {
                    'T1Radar',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarBuilders Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Radar T1 Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, (categories.RADAR + categories.OMNI) * categories.STRUCTURE}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T1Radar',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI SonarBuilders',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Sonar T1',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, (categories.STRUCTURE * categories.SONAR) + categories.MOBILESONAR } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.STRUCTURE * categories.NAVAL,
                AdjacencyDistance = 50,
                BuildClose = false,
                BuildStructures = {
                    'T1Sonar',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarUpgrade',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Radar Upgrade',
        PlatoonTemplate = 'T1RadarUpgrade',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Radar Upgrade',
        PlatoonTemplate = 'T2RadarUpgrade',
        Priority = 700,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 1200 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.2 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI SonarUpgrade',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Sonar Upgrade',
        PlatoonTemplate = 'T1SonarUpgrade',
        Priority = 600,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80 } },             -- Ratio from 0 to 1. (1=100%)
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.TECH1 * categories.SONAR }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Sonar Upgrade',
        PlatoonTemplate = 'T2SonarUpgrade',
        Priority = 400,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 1200 } },
            { MIBC, 'FactionIndex', { 1, 2, 3, 5 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconTrendOverTimeRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.90 } },             -- Ratio from 0 to 1. (1=100%)
            -- When do we want to build this ?
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.TECH2 * categories.MOBILESONAR }},
            -- Respect UnitCap
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarUpgrade T1 Expansion',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Radar Upgrade Expansion',
        PlatoonTemplate = 'T1RadarUpgrade',
        Priority = 600,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.5, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Radar Upgrade Expansion',
        PlatoonTemplate = 'T1RadarUpgrade',
        PriorityFunction = ActiveExpansion,
        Priority = 600,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.2 }},
        },
        BuilderType = 'Any',
    },
}