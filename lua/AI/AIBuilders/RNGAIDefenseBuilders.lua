--[[
    File    :   /lua/AI/AIBuilders/RNGAIDefenceBuilders.lua
    Author  :   relentless
    Summary :
        Defence Builders, for thos pesky units that slip past. Like bombers.
]]
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetOpAreaRNG()

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local ActiveExpansion = function(self, aiBrain, builderManager)
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --RNGLOG('Active Expansion is set'..builderManager.LocationType)
        --RNGLOG('Active Expansion builders are set to 900')
        return 900
    else
        --RNGLOG('Disable Air Intie Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

local NavalExpansionAdjust = function(self, aiBrain, builderManager)
    if aiBrain.MapWaterRatio < 0.20 then
        --RNGLOG('NavalExpansionAdjust return 0')
        return 0
    elseif aiBrain.MapWaterRatio < 0.30 then
        --RNGLOG('NavalExpansionAdjust return 200')
        return 200
    elseif aiBrain.MapWaterRatio < 0.40 then
        --RNGLOG('NavalExpansionAdjust return 400')
        return 400
    elseif aiBrain.MapWaterRatio < 0.60 then
        --RNGLOG('NavalExpansionAdjust return 650')
        return 650
    else
        --RNGLOG('NavalExpansionAdjust return 750')
        return 750
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Base Defenses',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Engineer Restricted Breach Land',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.DIRECTFIRE}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.6 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = true,
                OrderedTemplate = true,
                NearDefensivePoints = true,
                Type = 'Land',
                Tier = 1,
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
        BuilderName = 'RNGAI T1 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Land',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LANDNAVAL' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 0.6 }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 18, categories.DEFENSE * categories.TECH2 * categories.DIRECTFIRE}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                BaseTemplate = 'DefenseTemplate',
                OrderedTemplate = true,
                NearDefensivePoints = true,
                Type = 'Land',
                Tier = 2,
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = true,
                BuildStructures = {
                    'T2GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 6, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = true,
                NearDefensivePoints = false,
                BuildStructures = {
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Snipe Air',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyAirSnipeIsRiskActive', { }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'EnemyAirSnipeDefenceRequired', { 'MAIN' }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                BaseTemplate = 'DefenseTemplate',
                DesiresAssist = true,
                NumAssistees = 4,
                NoPause = true,
                BuildClose = false,
                OrderedTemplate = true,
                NearDefensivePoints = true,
                Type = 'AntiAir',
                Tier = 2,
                LocationType = 'LocationType',
                BuildStructures = {
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer ACUClose Artillery',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 800,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderConditions = {
            { TBC, 'EnemyACUCloseToBase', {}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.TECH2 * categories.ARTILLERY}},
        },
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                maxUnits = 1,
                maxRadius = 35,
                NearDefensivePoints = true,
                Type = 'Land',
                Tier = 1,
                BuildStructures = {
                    'T2Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 6, categories.DEFENSE * categories.TECH3 * categories.ANTIAIR}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = true,
                NearDefensivePoints = false,
                BuildStructures = {
                    'T3AADefense',
                },
                AdjacencyPriority = {categories.STRUCTURE * (categories.SHIELD + categories.FACTORY)},
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer TMD',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.1}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                BaseTemplate = 'DefenseTemplate',
                BuildClose = true,
                NearDefensivePoints = true,
                Type = 'TML',
                Tier = 1,
                BuildStructures = {
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Reactive TMD',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 7, categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE}},
            { UCBC, 'LastKnownUnitDetection', { 'LocationType', 'tml'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                BaseTemplate = 'DefenseTemplate',
                BuildClose = true,
                NoPause = true,
                NearDefensivePoints = true,
                Type = 'TML',
                Tier = 1,
                BuildStructures = {
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.TACTICALMISSILEPLATFORM}},
            { UCBC, 'CheckTargetInRangeRNG', { 'LocationType', 'T2StrategicMissile', categories.COMMAND + categories.STRUCTURE * (categories.TECH2 + categories.TECH3) } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.1}},
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 400, 4000 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.80}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                BaseTemplate = 'DefenseTemplate',
                BuildClose = true,
                NearDefensivePoints = true,
                Type = 'STRUCTURE',
                Tier = 1,
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH3 + categories.TECH2)},
                AvoidCategory = categories.STRUCTURE * categories.FACTORY,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Base D Engineer AA',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 12, categories.DEFENSE * categories.TECH3 * categories.ANTIAIR}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                NearDefensivePoints = false,
                maxUnits = 1,
                AdjacencyPriority = {categories.STRUCTURE * (categories.SHIELD + categories.FACTORY)},
                BuildStructures = {
                    'T3AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim Enemy Walls',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimUnitsAIRNG',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'HaveUnitsWithCategoryAndAllianceRNG', { true, 10, categories.WALL, 'Enemy'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'Reclaim',
            Radius = 1000,
            Categories = {categories.WALL},
            ThreatMin = -10,
            ThreatMax = 10000,
            ThreatRings = 1,
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Base Defenses Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Land Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.DEFENSE * categories.DIRECTFIRE}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = false,
                NearDefensivePoints = false,
                OrderedTemplate = true,
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
        BuilderName = 'RNGAI T1 Defence Restricted Breach Air Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.DEFENSE * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Sea Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.DEFENSE * categories.ANTINAVY}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'NAVAL' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                NearDefensivePoints = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY * categories.NAVAL},
                AvoidCategory = categories.STRUCTURE * categories.NAVAL * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Land Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LANDNAVAL' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.DIRECTFIRE}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    'T2GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Air Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Expansion TML',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.TACTICALMISSILEPLATFORM}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.05}},
            { UCBC, 'CheckTargetInRangeRNG', { 'LocationType', 'T2StrategicMissile', categories.STRUCTURE + (categories.LAND * (categories.TECH2 + categories.TECH3)) } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer TMD Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.0}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 2,
            Construction = {
                BuildClose = true,
                NearDefensivePoints = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY},
                AvoidCategory = categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH2 * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}


-- Defenses surrounding the base in patrol points
--[[
BuilderGroup {
    BuilderGroupName = 'RNGAI Perimeter Defenses Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Land - Perimeter',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80, 'DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 40,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Sea - Perimeter',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PriorityFunction = NavalExpansionAdjust,
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.ANTINAVY}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80, 'DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 120,
                BuildStructures = {
                    'T1AADefense',
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer - Perimeter',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 12, categories.DEFENSE * categories.TECH2}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80, 'DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE * categories.TECH2 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 45,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Perimeter Defenses Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Land - Perimeter Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80, 'DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 40,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer - Perimeter Large',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 12, categories.DEFENSE * categories.TECH2}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.80, 'DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE * categories.TECH2 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 45,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Perimeter Defenses Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Land - Perimeter Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 40,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Sea - Perimeter Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.NAVAL}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                BaseTemplate = 'ExpansionBaseTemplates',
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 120,
                BuildStructures = {
                    'T1AADefense',
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer - Perimeter Large',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 12, 'DEFENSE TECH2'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}},
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE TECH2' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 45,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}
]]
BuilderGroup {
    BuilderGroupName = 'RNGAI Perimeter Defenses Expansions',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Land - Perimeter Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.70}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 18,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Artillery Counter',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.0 }},
            { UCBC, 'DefensiveClusterCloseRNG', {'LocationType'}},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.STRUCTURE * categories.TECH2 * categories.ARTILLERY}},
        },
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH2,
                maxUnits = 1,
                maxRadius = 35,
                BuildStructures = {
                    'T2Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Sea - Perimeter Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PriorityFunction = NavalExpansionAdjust,
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.ANTINAVY}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80, 'DEFENSE'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 120,
                BuildStructures = {
                    'T1AADefense',
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer - Perimeter Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 12, categories.DEFENSE * categories.TECH2}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80}},
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE * categories.TECH2 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 14,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T12 Perimeter Defenses Naval',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Sea - Perimeter Naval',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PriorityFunction = NavalExpansionAdjust,
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.ANTINAVY}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 80,
                BuildStructures = {
                    'T1AADefense',
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Sea - Perimeter Naval',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        PriorityFunction = NavalExpansionAdjust,
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.ANTINAVY}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 60,
                BuildStructures = {
                    'T2AADefense',
                    'T2NavalDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Sea',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'NAVAL' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.ANTINAVY}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY * categories.NAVAL},
                AvoidCategory = categories.STRUCTURE * categories.ANTINAVY * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 3,
                BuildStructures = {
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Restricted Breach Sea',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'NAVAL' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.DEFENSE * categories.TECH2 * categories.ANTINAVY}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY * categories.NAVAL},
                AvoidCategory = categories.STRUCTURE * categories.ANTINAVY * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 3,
                BuildStructures = {
                    'T2NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Restricted Breach Cruisers',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL * categories.CRUISER * (categories.UEF + categories.SERAPHIM) - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 6, categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY * categories.NAVAL},
                AvoidCategory = categories.STRUCTURE * categories.NAVAL * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Defense FormBuilders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T2 TML Silo',
        PlatoonTemplate = 'AddToTMLPlatoonRNG',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 100,
        BuilderConditions = {
            -- Have we the eco to build it ?
            -- When do we want to build this ?
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM * categories.TECH2 } },
        },
        BuilderData = {
            PlatoonPlan = 'TMLAIRNG',
            Location = 'LocationType'
        },
        BuilderType = 'Any',
    },
    
    Builder {
        BuilderName = 'RNGAI T2 Artillery',
        PlatoonTemplate = 'T2ArtilleryStructure',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 10000,
        BuilderConditions = {
            -- Have we the eco to build it ?
            -- When do we want to build this ?
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.INDIRECTFIRE * categories.TECH2 } },
        },
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI SMD Builders',                               
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI SMD 1st Main',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 } },
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50, 'DEFENSE' } },             -- Ratio from 0 to 1. (1=100%)
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 5,
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3},
                AdjacencyDistance = 80,
                AvoidCategory = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3StrategicMissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI SMD Response',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { UCBC, 'HaveUnitRatioVersusEnemyRNG', { 0.50, 'LocationType', 180, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3, '<', categories.SILO * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 8,
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3},
                AdjacencyDistance = 80,
                AvoidCategory = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3StrategicMissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}