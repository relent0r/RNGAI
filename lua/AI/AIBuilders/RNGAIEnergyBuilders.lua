--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local HydroPriorityModifier = function(self, aiBrain, builderManager)
    local numUnits = aiBrain:GetCurrentUnits(categories.ENERGYPRODUCTION * categories.HYDROCARBON)
    if numUnits < 1 and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime < 15 then
        return 997
    end
    return 950
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Trend OverTime',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 90 } },
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 28.0 } }, -- If our energy is trending into negatives
            { EBC, 'GreaterThanMassStorageOrEfficiency', { 225, 0.95 }},
            { UCBC, 'ValidateHydroIncome', { categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.HYDROCARBON) } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) - categories.HYDROCARBON }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildClose = true,
                EcoSelector = 'ENERGY',
                AdjacencyPriority = {
                    categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.FACTORY * categories.LAND,
                    categories.MASSEXTRACTION * categories.TECH1,
                    categories.ENERGYSTORAGE,   
                    categories.INDIRECTFIRE * categories.DEFENSE,
                    categories.SHIELD * categories.STRUCTURE,
                },
                --Scale = true,
                AvoidCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION,
                AdjacencyDistance = 15,
                maxUnits = 1,
                maxRadius = 2.5,
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Trend Instant',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1050,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 90 } },
            { EBC, 'NegativeEcoPowerCheckInstant', { 15.0 } }, -- If our energy is trending into negatives
            { UCBC, 'ValidateHydroIncome', { categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.HYDROCARBON) } },
            { UCBC, 'PowerBuildCapabilityExist', { categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) - categories.HYDROCARBON, categories.ENGINEER * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                BuildClose = true,
                EcoSelector = 'ENERGY',
                AdjacencyPriority = {
                    categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.MASSEXTRACTION * categories.TECH1,
                    categories.FACTORY * categories.LAND,
                    categories.ENERGYSTORAGE,   
                    categories.INDIRECTFIRE * categories.DEFENSE,
                    categories.SHIELD * categories.STRUCTURE,
                },
                AvoidCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION,
                AdjacencyDistance = 10,
                maxUnits = 1,
                maxRadius = 2.5,
                BuildCategory = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE,
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 1055,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT2', 6},
        BuilderConditions = {
            { EBC, 'NegativeEcoPowerCheck', { 45.0 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.1 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) - categories.HYDROCARBON }},
            { UCBC, 'PowerBuildCapabilityExist', { categories.STRUCTURE * categories.ENERGYPRODUCTION *  categories.TECH3 - categories.HYDROCARBON, categories.ENGINEER * categories.TECH3 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            DesiresAssist = true,
            NumAssistees = 15,
            Construction = {
                --AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                --AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                AdjacencyBias = 'Back',
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.FACTORY * categories.STRUCTURE,
                },
                AvoidCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2,
                EcoSelector = 'ENERGY',
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    { Unit = 'T2EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH2 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Scale',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 800,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT2', 6},
        BuilderConditions = {
            { EBC, 'LessThanEnergyTrendCombinedRNG', { 120.0 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.10}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 3, categories.ENERGYPRODUCTION * categories.TECH2, 1, categories.ENERGYPRODUCTION * categories.TECH3 - categories.HYDROCARBON }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION *  categories.TECH3 - categories.HYDROCARBON }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            DesiresAssist = true,
            EcoSelector = 'ENERGY',
            NumAssistees = 12,
            Construction = {
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.FACTORY * categories.STRUCTURE,
                },
                maxUnits = 1,
                maxRadius = 4,
                BuildStructures = {
                    { Unit = 'T2EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH2 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Negative Trend',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 1060,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT3', 6},
        BuilderConditions = {
            { EBC, 'NegativeEcoPowerCheck', { 180.0 } },
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 - categories.HYDROCARBON }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.1 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            DesiresAssist = true,
            NumAssistees = 20,
            Construction = {
                --AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                --AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
                AdjacencyBias = 'Back',
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.TECH2,
                    categories.FACTORY * categories.STRUCTURE,
                },
                EcoSelector = 'ENERGY',
                maxUnits = 1,
                maxRadius = 15,
                BuildStructures = {
                    { Unit = 'T3EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH3 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Power Engineer Scale',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 700,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'EnergyT3', 6},
        BuilderConditions = {
            { EBC, 'LessThanEnergyTrendCombinedRNG', { 500.0, true } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 0.8 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.10}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3 - categories.HYDROCARBON }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.ENERGYPRODUCTION * categories.TECH3 - categories.HYDROCARBON }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                AdjacencyPriority = {
                    categories.SHIELD * categories.STRUCTURE,
                    categories.STRUCTURE * categories.FACTORY * categories.AIR,
                    categories.RADAR * categories.STRUCTURE,
                    categories.ENERGYPRODUCTION * categories.TECH2,
                    categories.FACTORY * categories.STRUCTURE,
                },
                EcoSelector = 'ENERGY',
                maxUnits = 1,
                maxRadius = 15,
                BuildStructures = {
                    { Unit = 'T3EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH3 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Builder Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Pgen Scale Expansion',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 900,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 28.0 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 0.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) - categories.HYDROCARBON }}, -- Don't build after 1 T2 Pgens Exist
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                AdjacencyPriority = {categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND)},
                AdjacencyDistance = 50,
                EcoSelector = 'ENERGY',
                BuildStructures = {
                    { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Power Engineer Expansion',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 800,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.1, 0.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.0}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.ENERGYPRODUCTION *  categories.TECH3 - categories.HYDROCARBON }},
            { EBC, 'LessThanEnergyTrendCombinedRNG', { 0.0 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.TECH2 * categories.ENERGYPRODUCTION - categories.HYDROCARBON }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD, categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)},
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                EcoSelector = 'ENERGY',
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    { Unit = 'T2EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH2 * categories.STRUCTURE - categories.HYDROCARBON },
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Hydro Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Hydro 60',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1051,
        DelayEqualBuildPlattons = {'Energy', 3},
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistanceRNG', { 'LocationType', 65, 1, 'AntiSurface'}},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                EcoSelector = 'ENERGY',
                BuildStructures = {
                    { Unit = 'T1HydroCarbon', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE * categories.HYDROCARBON },
                },
            }
        }

    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Hydro 120',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 950,
        PriorityFunction = HydroPriorityModifier,
        DelayEqualBuildPlattons = {'Energy', 3},
        InstanceCount = 1,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistanceRNG', { 'LocationType', 120, 1, 'AntiSurface'}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            NeedGuard = false,
            DesiresAssist = true,
            Construction = {
                EcoSelector = 'ENERGY',
                BuildStructures = {
                    { Unit = 'T1HydroCarbon', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE * categories.HYDROCARBON },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Hydro 250',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 780,
        DelayEqualBuildPlattons = {'Energy', 3},
        InstanceCount = 2,
        BuilderConditions = { 
            { UCBC, 'CanBuildOnHydroLessThanDistanceRNG', { 'LocationType', 256, 1, 'AntiSurface'}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 0.1 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildPower',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                EcoSelector = 'ENERGY',
                BuildStructures = {
                    { Unit = 'T1HydroCarbon', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE * categories.HYDROCARBON },
                },
            }
        }

    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Energy Storage Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG T1 Energy Storage Builder OverCharge',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 1000,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYSTORAGE }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = false,
                NoPause = true,
                BuildStructures = {
                    { Unit = 'EnergyStorage', Categories = categories.ENERGYSTORAGE * categories.TECH1 * categories.STRUCTURE },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Energy Storage Builder OverCharge Power',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 850,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.ENERGYSTORAGE }},
            { EBC, 'GreaterThanEconEfficiencyOrAirStrategyRNG', { 0.9, 1.1 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'EnergyStorage', Categories = categories.ENERGYSTORAGE * categories.TECH1 * categories.STRUCTURE },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Energy Storage Builder',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 750,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.1 }},
            { UCBC, 'RequireEnergyStorage', { }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'EnergyStorage', Categories = categories.ENERGYSTORAGE * categories.TECH1 * categories.STRUCTURE },
                },
            }
        }
    },
}
