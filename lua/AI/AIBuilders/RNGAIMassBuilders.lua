--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 45',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1005,
        InstanceCount = 2,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 45, nil, nil, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 45,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 5,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 80',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 3,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 80, nil, nil, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 80,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 120',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 992,
        InstanceCount = 3,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 120, nil, nil, 0, 'AntiSurface', 1}},
            --{ UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                BuildClose = true,
                Type = 'Mass',
                MaxDistance = 120,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 400 MexBuild',
        PlatoonTemplate = 'EngineerBuilderRNGMex',
        Priority = 997,
        InstanceCount = 3,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 400, -500, 2, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Type = 'Mass',
                MaxDistance = 400,
                ThreatMin = -500,
                ThreatMax = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2Engineer Mass 120',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 120, nil, nil, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.ENGINEER * (categories.TECH2 + categories.TECH3) - categories.COMMAND }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 120,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T2Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 240',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 800,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 240, nil, nil, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Type = 'Mass',
                MaxDistance = 240,
                MinDistance = 60,
                ThreatMin = -500,
                ThreatMax = 2,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 480',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 4,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTimeRNG', { 180 } },
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 60, 480, -500, 2, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND }},
            
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                MexThreat = true,
                Type = 'Mass',
                MaxDistance = 480,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 2,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 2000',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 300,
        InstanceCount = 4,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 100, 2000, -500, 2, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 2, categories.ENGINEER - categories.COMMAND }},
            
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                BuildClose = true,
                MexThreat = true,
                Type = 'Mass',
                MaxDistance = 2000,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 4,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
}


BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Fab',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Mass Fab',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MassFab', 7},
        BuilderConditions = {
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassFab' }},
            { UCBC, 'GreaterThanT3CoreExtractorPercentage', { 0.85 }},
            { EBC, 'GreaterThanEnergyTrendOverTimeRNG', { 160.0 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveUnitRatioRNG', { 0.3, categories.STRUCTURE * categories.MASSFABRICATION, '<=',categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.95}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'LessThanEconStorageRatioRNG', { 0.10, 2 } },
            -- Don't build it if...
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.MASSFABRICATION } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 4,
            Construction = {
                DesiresAssist = true,
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3},
                AdjacencyDistance = 80,
                AvoidCategory = categories.MASSFABRICATION,
                maxUnits = 1,
                maxRadius = 15,
                BuildClose = true,
                BuildStructures = {
                    'T3MassCreation',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder Floating',
    BuildersType = 'EngineerBuilder',
    
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 2000 Floating',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 910,
        InstanceCount = 5,
        BuilderConditions = {
                { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 100, 2000, -500, 2, 0, 'AntiSurface', 1}},
            },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 2000,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
                CheckCivUnits = true
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 2000 Floating Excess',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 890,
        InstanceCount = 10,
        BuilderConditions = {
                { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 100, 2000, -500, 2, 0, 'AntiSurface', 1}},
            },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 2000,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
                CheckCivUnits = true
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 30 Expansion',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = {
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 30, -500, 2, 0, 'AntiSurface', 1}},
            },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MexThreat = true,
                MaxDistance = 30,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 150 Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 2,
        BuilderConditions = {
                { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0,  150, nil, nil, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 150,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 2000 Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 550,
        InstanceCount = 2,
        BuilderConditions = {
                { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 100, 2000, -500, 2, 0, 'AntiSurface', 1}},
            },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 2000,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Storage Builder',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Engineer Single',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 930,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 1,
        BuilderConditions = {
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 150 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.80, 0.85 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 100, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                BaseTemplate = 'CappedExtractorTemplate',
                BuildClose = false,
                CappingTemplate = true,
                Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                NearDefensivePoints = false,
                NoPause = true,
                Radius = 150,
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',

                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 925,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 1,
        BuilderConditions = {
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 150 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.85, 0.90 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 100, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                Construction = {
                    BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                    BaseTemplate = 'CappedExtractorTemplate',
                    BuildClose = false,
                    CappingTemplate = true,
                    Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                    NearDefensivePoints = false,
                    NoPause = true,
                    Radius = 150,
                    BuildStructures = {
                        'MassStorage',
                        'MassStorage',
                        'MassStorage',
                        'MassStorage',
    
                    },
                    Location = 'LocationType',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNG T2 Mass Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 945,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 1,
        BuilderConditions = {
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.MASSEXTRACTION * categories.TECH3}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 80 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 100, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                BaseTemplate = 'CappedExtractorTemplate',
                BuildClose = false,
                CappingTemplate = true,
                Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                Radius = 80,
                NearDefensivePoints = false,
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',

                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Engineer Distant',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 400,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 2,
        BuilderConditions = {
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 500 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 500, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                BaseTemplate = 'CappedExtractorTemplate',
                BuildClose = false,
                CappingTemplate = true,
                Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                Radius = 80,
                NearDefensivePoints = false,
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',

                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Excess',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION'}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 150, -3, 0, 0}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.50, 0.20}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION, 150, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                BaseTemplate = 'CappedExtractorTemplate',
                BuildClose = false,
                CappingTemplate = true,
                Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                Radius = 80,
                NearDefensivePoints = false,
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',

                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Storage Builder Expansion',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Engineer Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 925,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 2,
        BuilderConditions = {
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 150 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 100, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                BaseTemplate = 'CappedExtractorTemplate',
                BuildClose = false,
                CappingTemplate = true,
                Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                Radius = 80,
                NearDefensivePoints = false,
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',

                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Engineer Distant Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 400,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 2,
        BuilderConditions = {
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 500 }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 500, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                BaseTemplate = 'CappedExtractorTemplate',
                BuildClose = false,
                CappingTemplate = true,
                Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                Radius = 80,
                NearDefensivePoints = false,
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',

                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Storage Builder Floating',
    BuildersType = 'EngineerBuilder',
    
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Floating',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 905,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 1,
        BuilderConditions = {
            --{ UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 'BaseDMZArea' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.95, 1.05 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'MAIN', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 'BaseDMZArea', 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua',
                BaseTemplate = 'CappedExtractorTemplate',
                BuildClose = false,
                CappingTemplate = true,
                Categories = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                NearDefensivePoints = false,
                NoPause = true,
                Radius = 150,
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',

                },
                Location = 'MAIN',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGEXP Crazyrush Builder',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGEXP T1 Mex Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        InstanceCount = 12,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSEXTRACTION}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 150 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatioRNG', { 1, 1.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 200, categories.MASSEXTRACTION}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION, 100, 'ueb1103' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            Construction = {
                AdjacencyCategory = categories.MASSEXTRACTION,
                AdjacencyDistance = 100,
                BuildClose = false,
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGEXP T1 Mex Adjacency Engineer Distant',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 400,
        InstanceCount = 12,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSEXTRACTION}},
            { MABC, 'MassMarkerLessThanDistanceRNG',  { 500 }},
            { EBC, 'LessThanEconStorageRatioRNG', { 0.2, 1.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 200, categories.MASSEXTRACTION}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyMassCheckRNG', { 'LocationType', categories.MASSEXTRACTION, 500, 'ueb1103' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Mass',
            Construction = {
                AdjacencyPriority = categories.MASSEXTRACTION,
                AdjacencyDistance = 500,
                BuildClose = false,
                ThreatMin = -3,
                ThreatMax = 0,
                ThreatRings = 0,
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
}
