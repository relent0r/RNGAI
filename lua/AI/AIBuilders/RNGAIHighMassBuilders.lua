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
    BuilderGroupName = 'RNGAIR Mass Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAIR T1Engineer Mass 30',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        InstanceCount = 2,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 0, 0, 'AntiSurface', 1}},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 1, 1.1 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 30,
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
        BuilderName = 'RNGAIR T1Engineer Mass 60',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 60, -500, 0, 0, 'AntiSurface', 1}},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 1, 1.1 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 60,
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
        BuilderName = 'RNGAIR T1Engineer Mass 120',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 850,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 120, -500, 0, 0, 'AntiSurface', 1}},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 1, 1.1 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 120,
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
        BuilderName = 'RNGAIR T1Engineer Mass 240',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 800,
        InstanceCount = 6,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 240, -500, 2, 0, 'AntiSurface', 1}},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 1, 1.1 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 120,
                Type = 'Mass',
                MaxDistance = 240,
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
        BuilderName = 'RNGAIR T1Engineer Mass 480',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 6,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTimeRNG', { 180 } },
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 480, -500, 2, 30, 'AntiSurface', 1}},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 1, 1.1 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 120,
                Type = 'Mass',
                MaxDistance = 480,
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
        BuilderName = 'RNGAIR T1Engineer Mass 2000',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 300,
        InstanceCount = 7,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 2000, -500, 10, 0, 'AntiSurface', 1}},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 1, 1.1 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 1000,
                ThreatMin = -500,
                ThreatMax = 10,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
}


BuilderGroup {
    BuilderGroupName = 'RNGAIR Mass Fab',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAIR Mass Fab',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MassFab', 7},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassFab' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.95}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'LessThanEconStorageRatio', { 0.10, 2 } },
            -- Don't build it if...
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.MASSFABRICATION } },
            -- Respect UnitCap
            { UCBC, 'HaveUnitRatioVersusCapRNG', { 0.10 , '<', categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSFABRICATION) } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.5 }},
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
}
