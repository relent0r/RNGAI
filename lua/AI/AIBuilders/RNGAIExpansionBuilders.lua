--[[
    File    :   /lua/AI/AIBuilders/RNGAIExpansionBuilders.lua
    Author  :   relentless
    Summary :
        Expansion Base Templates
]]

local ExBaseTmpl = 'ExpansionBaseTemplates'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Expansion Builders Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Vacant Expansion Area 350 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'ExpansionAreaNeedsEngineer', { 'LocationType', 350, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },            
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Expansion Area',
                ExpansionRadius = 60, -- Defines the radius of the builder managers to avoid them intruding on another base if the expansion marker is too close
                LocationRadius = 350,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 2,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 250 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 250, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 250 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 250, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area 250 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'NavalAreaNeedsEngineer', { 'LocationType', 250, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1SeaFactory',
                }
            },
            NeedGuard = false,
        }
    },
    --[[
    Builder {
        BuilderName = 'RNGAI T1 Unmarked Expansion Area 1000 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'UnmarkedExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Unmarked Expansion',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },]]
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 1000 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 1000 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Expansion Builders Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area 350 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'NavalAreaNeedsEngineer', { 'LocationType', 350, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                LocationRadius = 350, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1SeaFactory',
                    'T1NavalDefense',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 500 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 750,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 500, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                LocationRadius = 500, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 500 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 500, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                LocationRadius = 500, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 1000 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 1000 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 500,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = false,
        }
    },
    --[[
    Builder {
        BuilderName = 'RNGAI T1 Unmarked Expansion Area 1000 Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * categories.TECH1 - categories.COMMAND - categories.STATIONASSISTPOD }},
            { UCBC, 'UnmarkedExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 10, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Unmarked Expansion',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 10,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },]]
}