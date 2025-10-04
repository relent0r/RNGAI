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
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --RNGLOG('Active Expansion is set'..builderManager.LocationType)
        --RNGLOG('Active Expansion builders are set to 900')
        return 900
    else
        --RNGLOG('Disable Air Intie Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarBuilders',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Radar T1',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, (categories.RADAR + categories.OMNI) * categories.STRUCTURE}},
            { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { MIBC, 'GreaterThanGameTimeRNG', { 180 } },
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION},
                AdjacencyDistance = 70,
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1Radar', Categories = categories.RADAR * categories.TECH1 * categories.STRUCTURE },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Radar T2',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 645,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, (categories.RADAR + categories.OMNI) * categories.STRUCTURE}},
            { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION},
                AdjacencyDistance = 70,
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T2Radar', Categories = categories.RADAR * categories.TECH2 * categories.STRUCTURE },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Radar T3',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 650,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, (categories.RADAR + categories.OMNI) * categories.STRUCTURE }},
            { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.4 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION},
                AdjacencyDistance = 70,
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T3Radar', Categories = categories.OMNI * categories.TECH3 * categories.STRUCTURE },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Radar T3 Optics',
        PlatoonTemplate = 'EngineerStateAeonT3SACURNG',
        Priority = 650,
        BuilderConditions = {
            { UCBC, 'StructureBuildDemand', { 'Structure', 'intel', 'Optics'} },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.AEON * categories.OPTICS * categories.STRUCTURE}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.05, 1.3 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 5.5, 650.0 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION},
                AdjacencyDistance = 70,
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T3Optics', Categories = categories.AEON * categories.OPTICS * categories.STRUCTURE },
                },
                LocationType = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI RadarBuilders Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Radar T1 Expansion',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 850,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, (categories.RADAR + categories.OMNI) * categories.STRUCTURE, 45}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1Radar', Categories = categories.RADAR * categories.TECH1 * categories.STRUCTURE },
                },
                LocationType = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI SonarBuilders',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Sonar T1',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, (categories.STRUCTURE * categories.SONAR) + categories.MOBILESONAR } },
            { UCBC, 'GreaterThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.NAVAL},
                AdjacencyDistance = 50,
                BuildClose = false,
                BuildStructures = {
                    { Unit = 'T1Sonar', Categories = categories.SONAR * categories.TECH1 * categories.STRUCTURE },
                },
                LocationType = 'LocationType',
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
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
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
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.2 }},
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
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } }, -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80 } },             -- Ratio from 0 to 1. (1=100%)
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
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } }, -- relative income
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
        BuilderName = 'RNGAI T1 Radar Upgrade Expansion Active',
        PlatoonTemplate = 'T1RadarUpgrade',
        PriorityFunction = ActiveExpansion,
        Priority = 0,
        BuilderConditions = {
            { UCBC, 'ShouldUpgradeRadar', {'LocationType', 'TECH2'}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.2 }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T1 Radar Upgrade Expansion',
        PlatoonTemplate = 'T1RadarUpgrade',
        Priority = 600,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { UCBC, 'ShouldUpgradeRadar', {'LocationType', 'TECH2'}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.TECH2 * categories.RADAR}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.5, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.9, 1.2 }},
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Intel Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Optics Former',
        PlatoonTemplate = 'T3OpticsStructureRNG',
        Priority = 10,
        InstanceCount = 1,
        FormRadius = 160,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.AEON * categories.OPTICS * categories.STRUCTURE } },
        },
        BuilderData = {
            StateMachine = 'Optics',
            LocationType = 'LocationType'
        },
        BuilderType = 'Any',
    },
}