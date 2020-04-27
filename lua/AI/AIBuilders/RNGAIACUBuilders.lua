--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local SAI = '/lua/ScenarioPlatoonAI.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 0M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 0 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 1M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 1 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 2M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 2 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 3M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 3 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 4M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 4 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Prebuilt Land Standard Small Close',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'PreBuiltBase', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 0M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 0 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 1M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 1 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 2M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 2 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 3M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 3 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 4M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 4 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Prebuilt Land Standard Large',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'PreBuiltBase', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconIncome',  { 0.5, 5.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.10}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.7 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH1' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconIncome',  { 0.7, 8.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Lower Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.15}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconIncome',  { 0.7, 8.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Air Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.20}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.TECH1 * categories.ENERGYPRODUCTION } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Air Factory Lower Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'GreaterThanEnergyTrend', { 0.0 } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'FACTORY AIR TECH1' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU Mass 20',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 0, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Trend'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Scale',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { MIBC, 'GreaterThanGameTime', { 120 } },
            { EBC, 'LessThanEnergyTrendRNG', { 10.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Scale'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Land',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = true,
                OrderedTemplate = true,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Air',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Higher Pri Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconIncome',  { 0.5, 5.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.30}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH1' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.TECH1 * categories.ENERGYPRODUCTION } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Higher Pri Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Factories' }},
            { EBC, 'GreaterThanEconIncome',  { 0.5, 5.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Air Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.20}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.TECH1 * categories.ENERGYPRODUCTION } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU Mass 20',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 0, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Trend'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Scale',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { MIBC, 'GreaterThanGameTime', { 120 } },
            { EBC, 'LessThanEnergyTrendRNG', { 10.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Scale'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', true }},
            { UCBC, 'CheckBuildPlatoonDelay', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'EngineerLessAtLocation', { 'LocationType', 3, 'TECH3 ENGINEER' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 2, 'ENERGYPRODUCTION TECH2, ENERGYPRODUCTION TECH3' }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, 'ENERGYPRODUCTION TECH3' }},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.5 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.7 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
            AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
            maxUnits = 1,
            maxRadius = 10,
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Land',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = true,
                OrderedTemplate = true,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Air',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Build Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Engineer',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.6}},
            { UCBC, 'GreaterThanMassTrend', { 0.0 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = categories.ENGINEER,
                AssistRange = 30,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },--[[
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Factory',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ALLUNITS'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Structure',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.6} },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Structure',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },]]
}

BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU Enhancements Gun',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'UEF CDR Enhancement HeavyAntiMatter',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'HeavyAntiMatterCannon', false }},
                { MIBC, 'FactionIndex', {1}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'HeavyAntiMatterCannon' },
        },

    },
    Builder {
        BuilderName = 'Aeon CDR Enhancement Crysalis',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'CrysalisBeam', false }},
                { MIBC, 'FactionIndex', {2}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            TimeBetweenEnhancements = 20,
            Enhancement = { 'HeatSink', 'CrysalisBeam'},
        },
    },
    Builder {
        BuilderName = 'Cybran CDR Enhancement CoolingUpgrade',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'CoolingUpgrade', false }},
                { MIBC, 'FactionIndex', {3}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'CoolingUpgrade'},
        },

    },
    Builder {
        BuilderName = 'Seraphim CDR Enhancement RateOfFire',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'RateOfFire', false }},
                { MIBC, 'FactionIndex', {4}},
            },
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderType = 'Any',
        BuilderData = {
            Enhancement = { 'RateOfFire' },
        },

    },
}

BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU Enhancements Tier',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'CDR Enhancement AdvancedEngineering Mid Game',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTime', { 1500 } },
                { UCBC, 'GreaterThanEnergyTrend', { 0.0 } },
                { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', false }},
                { EBC, 'GreaterThanEconIncome',  { 1.2, 120.0}},
                --{ MIBC, 'FactionIndex', {4}},
            },
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderType = 'Any',
        BuilderData = {
            Enhancement = { 'AdvancedEngineering' },
        },
    },
}
BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU Enhancements Tier Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'CDR Enhancement AdvancedEngineering Mid Game Large',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { UCBC, 'GreaterThanEnergyTrend', { 0.0 } },
                { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', false }},
                { EBC, 'GreaterThanEconIncome',  { 1.2, 120.0}},
                --{ MIBC, 'FactionIndex', {4}},
            },
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderType = 'Any',
        BuilderData = {
            Enhancement = { 'AdvancedEngineering' },
        },
    },
}

BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU PD1',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'PD with wall',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 990,
        BuilderConditions = {
            },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = true,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                },
                Location = 'LocationType',
            }
        },
    },
}