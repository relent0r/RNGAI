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
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

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
        --RNGLOG('We have a path to an enemy')
        return 1005
    else
        --RNGLOG('No path to an enemy')
        return 1010
    end
end


BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Small',
    BuildersType = 'EngineerBuilder',
    --[[
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small',
        PlatoonTemplate = 'CommanderInitializeRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
            }
        }
    },]]
    Builder {
        BuilderName = 'RNGAI CDR Initial Prebuilt Land Standard Small',
        PlatoonTemplate = 'CommanderStateMachineRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'PreBuiltBase', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            Construction = {
                MaxDistance = 30,
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR StateMachine Standard Small',
        PlatoonTemplate = 'CommanderStateMachineRNG',
        Priority = 1800,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.COMMAND}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            LocationType = 'LocationType',
            StateMachine = 'ACU'
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Prebuilt Land Standard Large',
        PlatoonTemplate = 'CommanderStateMachineRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'PreBuiltBase', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            Construction = {
                MaxDistance = 30,
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR StateMachine Standard Large',
        PlatoonTemplate = 'CommanderStateMachineRNG',
        Priority = 1800,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.COMMAND}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            LocationType = 'LocationType',
            StateMachine = 'ACU'
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG ACU Factory Builder Land T1 Primary',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1050,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'GreaterThanEconStorageCurrentRNG', { 240, 1050 } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * categories.TECH1 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Higher Pri',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'DisableOnStrategy', { {'T3AirRush'} }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * (categories.TECH1 + categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.5, 5.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Higher Pri'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Factory Builder Land T1 MainBase Storage',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1010,
        DelayEqualBuildPlattons = {'Factories', 3},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageCurrentRNG', { 240, 1050 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.70, 0.80 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR', 'EXPERIMENTAL'}, 1 } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.0, 5.5 }},
            --{ EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            --{ UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) - categories.SUPPORTFACTORY }},
         },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                LocationType = 'LocationType',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Lower Pri',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.30, 'FACTORY'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'PlayerRoleCheck', {'LocationType', 2, categories.FACTORY * categories.LAND, {'AIR', 'EXPERIMENTAL'}, 1 } },
            { EBC, 'GreaterThanMassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Primary',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1045,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.7, 12.0}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.85 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                BuildClose = true,
                AdjacencyPriority = {
                    categories.HYDROCARBON,
                    categories.ENERGYPRODUCTION * categories.STRUCTURE,
                },
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Higher Pri',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.7, 18.0}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.95 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                BuildClose = true,
                AdjacencyPriority = {
                    categories.HYDROCARBON,
                    categories.ENERGYPRODUCTION * categories.STRUCTURE,
                },
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Lower Pri',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'IsEngineerNotBuilding', {categories.FACTORY * categories.AIR * categories.TECH1}},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1AirFactory', Categories = categories.FACTORY * categories.AIR * categories.TECH1 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU Mass 60',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1005,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 60, nil, nil, 0, 'AntiSurface', 1}},
            { EBC, 'LessThanEconEfficiencyRNG', { 0.8, 2.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = false,
                MexThreat = true,
                Type = 'Mass',
                MaxDistance = 60,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 20,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    { Unit = 'T1Resource', Categories = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH1 },
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { EBC, 'MinimumPowerRequired', { 6.0 } },
            { EBC, 'GreaterThanMassStorageOrEfficiency', { 50, 0.7 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Scale',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { EBC, 'LessThanEnergyEfficiencyOverTimeRNG', { 1.3 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.90, 0.1 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                AvoidCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1,
                maxUnits = 1,
                maxRadius = 3,
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', true }},
            { EBC, 'NegativeEcoPowerCheck', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    { Unit = 'T2EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH2 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T3 Power Engineer Negative Trend',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'T3Engineering', true }},
            { EBC, 'NegativeEcoPowerCheck', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    { Unit = 'T3EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH3 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Land',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE}},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = true,
                OrderedTemplate = true,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    { Unit = 'T1GroundDefense', Categories = categories.STRUCTURE * categories.DIRECTFIRE * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 - categories.CIVILIAN},
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Air',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'ANTISURFACEAIR' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.DEFENSE * categories.AIR}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.7 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend Expansion',
        PlatoonTemplate = 'CommanderDummyRNG',
        Priority = 1000,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { EBC, 'NegativeEcoPowerCheckInstant', { 15.0 } }, -- If our energy is trending into negatives
            { UCBC, 'ValidateHydroIncome', { categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.HYDROCARBON) } },
            { UCBC, 'PowerBuildCapabilityExist', { categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) - categories.HYDROCARBON, categories.ENGINEER * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomACUBaseTemplates.lua',
                BaseTemplate = 'ACUCustomBaseTemplates',
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Build Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Assist Engineer',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'ACUAssist', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.2}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.MOBILE - categories.COMMAND } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssisteeType = categories.ENGINEER,
                AssistRange = 35,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ENERGYPRODUCTION, categories.MASSEXTRACTION, categories.FACTORY, categories.STRUCTURE * categories.DEFENSE},
                Time = 45,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist Assist Hydro',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 1000,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRadiusRNG', { 'LocationType', 0,65, categories.STRUCTURE * categories.HYDROCARBON, }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.HYDROCARBON }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG',  { 0.5, 0.0}},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
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
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.9}},
            { UCBC, 'FactoryGreaterAtLocationRNG', { 'LocationType', 0, categories.FACTORY * categories.STRUCTURE }},
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'PreAllocatedTask',
            PreAllocatedTask = true,
            Task = 'EngineerAssist',
            Assist = {
                AssisteeType = categories.FACTORY,
                AssistRange = 30,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ALLUNITS},
                Time = 20,
            },
        }
    },
}
