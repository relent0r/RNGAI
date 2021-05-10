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

local NavalAdjust = function(self, aiBrain, builderManager)
    local pathCount = 0
    if aiBrain.EnemyIntel.ChokePoints then
        for _, v in aiBrain.EnemyIntel.ChokePoints do
            if not v.NoPath then
                pathCount = pathCount + 1
            end
        end
    end
    if pathCount > 0 then
        --LOG('We have a path to an enemy')
        return 1005
    else
        --LOG('No path to an enemy')
        return 1010
    end
end


BuilderGroup {
    BuilderGroupName = 'RNG Tech Initial ACU Builder Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech CDR Initial Land Standard Small Close 0M',
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
                MaxDistance = 30,
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
        BuilderName = 'RNG Tech CDR Initial Land Standard Small Close 1M',
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
                MaxDistance = 30,
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
        BuilderName = 'RNG Tech CDR Initial Land Standard Small Close 2M',
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
                MaxDistance = 30,
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
        BuilderName = 'RNG Tech CDR Initial Land Standard Small Close 3M',
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
                MaxDistance = 30,
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
        BuilderName = 'RNG Tech CDR Initial Land Standard Small Close 4M',
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
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1Resource',
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
        BuilderName = 'RNG Tech CDR Initial Land Standard Small Close 5+M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 5 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech CDR Initial Prebuilt Land Standard Small Close',
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
                MaxDistance = 30,
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNG Tech ACU Structure Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech ACU T1 Land Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.STRUCTURE * categories.LAND * (categories.TECH1)}},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * (categories.TECH1 + categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconIncomeRNG',  { 0.5, 5.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.25}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.7 }},
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
        BuilderName = 'RNG Tech ACU T1 Land Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.30, 'FACTORY'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
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
        BuilderName = 'RNG Tech ACU T1 Air Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconIncomeRNG',  { 0.7, 8.0}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.0, 0.30}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.8 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
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
        BuilderName = 'RNG Tech ACU T1 Air Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Air Factory Lower Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, 'FACTORY AIR TECH1' }},
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
        BuilderName = 'RNG Tech ACU Mass 30',
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
                MaxDistance = 30,
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNG Tech ACU T1 Power Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION}},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH2 }},
            --{ UCBC, 'IsAcuBuilder', {'RNG Tech ACU T1 Power Trend'}},
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
        BuilderName = 'RNG Tech ACU T1 Power Scale',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            --{ UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { MIBC, 'GreaterThanGameTimeRNG', { 140 } },
            --{ EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 0.0 }},
            --{ EBC, 'LessThanEnergyTrendRNG', { 5.0 } }, -- If our energy is trending into negatives
            --{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH2 }},
            --{ UCBC, 'IsAcuBuilder', {'RNG Tech ACU T1 Power Scale'}},
            --{ MIBC, 'GreaterThanGameTimeRNG', { 180 } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyEfficiencyOverTimeRNG', { 1.3 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.80, 0.7 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH1,
                maxUnits = 1,
                maxRadius = 3,
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech ACU T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', true }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech ACU T3 Power Engineer Negative Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'T3Engineering', true }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG Tech T1 Defence ACU Restricted Breach Land',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
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
        BuilderName = 'RNG Tech T1 Defence ACU Restricted Breach Air',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
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
    BuilderGroupName = 'RNG Tech ACU Build Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG Tech CDR Assist T1 Engineer',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 950,
        DelayEqualBuildPlattons = {'ACUAssist', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.3}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = categories.ENGINEER,
                AssistRange = 30,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ENERGYPRODUCTION, categories.FACTORY},
                Time = 45,
            },
        }
    },
    Builder {
        BuilderName = 'RNG Tech CDR Assist Assist Hydro',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 960,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRadiusRNG', { 'LocationType', 0,65, categories.STRUCTURE * categories.HYDROCARBON, }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.HYDROCARBON }},
            { EBC, 'GreaterThanEconIncomeRNG',  { 0.5, 0.0}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 65,
                BeingBuiltCategories = {categories.STRUCTURE * categories.HYDROCARBON},
                AssistUntilFinished = true,
                Time = 0,
            },
        }
    },
    --[[
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = categories.FACTORY,
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ALLUNITS},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Structure',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.6} },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = categories.STRUCTURE',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ENERGYPRODUCTION, categories.FACTORY, categories.STRUCTURE * categories.DEFENSE},
                Time = 30,
            },
        }
    },]]
}