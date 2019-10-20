--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 30',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        InstanceCount = 2,
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
        BuilderName = 'RNGAI T1Engineer Mass 60',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 950,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 60, -500, 0, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
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
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        InstanceCount = 3,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 120, -500, 0, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
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
        BuilderName = 'RNGAI T1Engineer Mass 240',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 240, -500, 2, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
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
        BuilderName = 'RNGAI T1Engineer Mass 480',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        InstanceCount = 2,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTime', { 180 } },
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 480, -500, 2, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            
        },
        BuilderType = 'Any',
        BuilderData = {
            Categories = {categories.MOBILE * categories.LAND},
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
        BuilderName = 'RNGAI T1Engineer Mass 1000',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 700,
        InstanceCount = 2,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTime', { 420 } },
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 1000, -500, 2, 0, 'AntiSurface', 1}},
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, 'ENGINEER TECH1' }},
            
        },
        BuilderType = 'Any',
        BuilderData = {
            Categories = {categories.MOBILE * categories.LAND},
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
    BuilderGroupName = 'RNGAI Mass Builder Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'T1ResourceEngineer 150 Low',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 1000,
        InstanceCount = 2,
        BuilderConditions = {
                #{ UCBC, 'EngineerLessAtLocation', { 'LocationType', 4, 'ENGINEER TECH2, ENGINEER TECH3'}},
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
        BuilderName = 'T1ResourceEngineer 350 Low',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 700,
        InstanceCount = 2,
        BuilderConditions = {
                #{ UCBC, 'EngineerLessAtLocation', { 'LocationType', 4, 'ENGINEER TECH2, ENGINEER TECH3'}},
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 350, -500, 1, 0, 'AntiSurface', 1 }},
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
        BuilderName = 'T1ResourceEngineer 1000 Low',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
                #{ UCBC, 'EngineerLessAtLocation', { 'LocationType', 4, 'ENGINEER TECH2, ENGINEER TECH3'}},
                { MIBC, 'GreaterThanGameTime', { 420 } },
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 1000, -500, 1, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = true,
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
        BuilderName = 'T1 Mass Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, 'MASSEXTRACTION TECH2, MASSEXTRACTION TECH3'}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 100, -3, 0, 0}},
            { IBC, 'BrainNotLowPowerMode', {} },
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
