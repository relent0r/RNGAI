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

local AggressiveExpansion = function(self, aiBrain, builderManager)
    if aiBrain.coinFlip == 1 then
        --LOG('Aggressive Expansion is true'..' coin flip is '..aiBrain.coinFlip)
        return 1000
    else
        --LOG('Aggressive Expansion is false '..' coin flip is '..aiBrain.coinFlip)
        return 0
    end
end


BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Expansion Builders Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Vacant Expansion Area 350 Small',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
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
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 700,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
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
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
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
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', 250, -1000, 100, 1, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 80,
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
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
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
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
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
        BuilderName = 'RNGAI T1 Naval Expansion Area 450 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', 450, -1000, 100, 1, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 60,
                LocationRadius = 450, -- radius from LocationType to build
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
        BuilderName = 'RNGAI T1 Aggressive Expansion 250 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 0,
        PriorityFunction = AggressiveExpansion,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LessThanGameTimeSeconds', { 600 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR}},

            { MIBC, 'CanBuildAggressivebaseRNG', { 'LocationType', 250, -1000, 5, 1, 'AntiSurface'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                AggressiveExpansion = true, -- This is picked up so that a modified firebase function runs to pick the expansion closest to the enemy
                EnemyRange = 250,
                NearMarkerType = true, -- This is so the engineerbuildai will still pick up the expansion bool, the aggressive base check uses 3 types of expansion markers.
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                    'T1LandFactory',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Expansion Area 350 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
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
        BuilderName = 'RNGAI T1 Vacant Expansion Area 1000 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 500,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'ExpansionAreaNeedsEngineer', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
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
                LocationRadius = 1000,
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
        BuilderName = 'RNGAI T1 Vacant Starting Area 500 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 800,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
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
        BuilderName = 'RNGAI T1 Vacant Starting Area 2000 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 2000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                LocationRadius = 2000, -- radius from LocationType to build
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