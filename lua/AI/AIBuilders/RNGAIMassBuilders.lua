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

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 30',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        InstanceCount = 2,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 0, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
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
        BuilderName = 'RNGAI T1Engineer Mass 60',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 60, -500, 0, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
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
        BuilderName = 'RNGAI T1Engineer Mass 120',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 850,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 120, -500, 0, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 30,
                Type = 'Mass',
                BuildStructures = {
                    'T1Resource',
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
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 240, -500, 2, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 30,
                Type = 'Mass',
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
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 480, -500, 2, 30, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 30,
                Type = 'Mass',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 1000',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 300,
        InstanceCount = 4,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 1000, -500, 2, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            
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
}


BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Fab',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Mass Fab',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveUnitRatioRNG', { 0.3, categories.STRUCTURE * categories.MASSFABRICATION, '<=',categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.0, 0.95}}, -- Ratio from 0 to 1. (1=100%)
            -- Don't build it if...
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.MASSFABRICATION } },
            -- Respect UnitCap
            { UCBC, 'HaveUnitRatioVersusCap', { 0.10 , '<', categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSFABRICATION) } },
    
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 4,
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
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
    Builder {
        BuilderName = 'RNGAI Mass Fab Adja',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 400,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            -- Do we need additional conditions to build it ?
            { UCBC, 'HaveUnitRatioRNG', { 0.5, categories.STRUCTURE * categories.MASSFABRICATION, '<=',categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
            --{ UCBC, 'HasNotParagon', {} },
            -- Have we the eco to build it ?
            { EBC, 'LessThanMassTrendRNG', { 50.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.00, 0.95}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            -- Don't build it if...
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.MASSFABRICATION } },
            -- Respect UnitCap
            { UCBC, 'HaveUnitRatioVersusCap', { 0.10 , '<', categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSFABRICATION) } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 5,
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
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
    BuilderGroupName = 'RNGAI Mass Builder Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 30 Expansion',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * ( categories.TECH1 + categories.TECH2 ) - categories.COMMAND - categories.STATIONASSISTPOD }},
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 1, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 150 Expansion',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 700,
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * ( categories.TECH1 + categories.TECH2 ) - categories.COMMAND - categories.STATIONASSISTPOD }},
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 150, -500, 1, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 350 Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 660,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 350, -500, 10, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 30,
                Type = 'Mass',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 1000 Expansion',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 550,
        InstanceCount = 2,
        BuilderConditions = {
                { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * ( categories.TECH1 + categories.TECH2 ) - categories.COMMAND - categories.STATIONASSISTPOD }},
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 1000, -500, 50, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
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
        BuilderName = 'RNG T1 Mass Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1, ENGINEER TECH2, ENGINEER TECH3' }},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 150, -3, 0, 0}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.60}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyCheck', { 'LocationType', 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3', 100, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = 'MASSEXTRACTION TECH3, MASSEXTRACTION TECH2',
                AdjacencyDistance = 100,
                BuildClose = false,
                ThreatMin = -3,
                ThreatMax = 0,
                ThreatRings = 0,
                BuildStructures = {
                    'MassStorage',
                }
            }
        }
    },
}
