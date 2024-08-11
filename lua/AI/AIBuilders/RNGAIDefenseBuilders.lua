--[[
    File    :   /lua/AI/AIBuilders/RNGAIDefenceBuilders.lua
    Author  :   relentless
    Summary :
        Defence Builders, for thos pesky units that slip past. Like bombers.
]]

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
        PlatoonTemplate = 'EngineerStateT1RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.DIRECTFIRE}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.6 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T1GroundDefense', Categories = categories.STRUCTURE * categories.DIRECTFIRE * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'EngineerStateT1RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 240 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 1, 'AIR'}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    { Unit = 'T1AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Land',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LANDNAVAL' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 0.6 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 2, 'LANDNAVAL'}},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 18, categories.DEFENSE * categories.TECH2 * categories.DIRECTFIRE}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T2GroundDefense', Categories = categories.STRUCTURE * categories.DIRECTFIRE * categories.DEFENSE * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 2, 'AIR'}},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 6, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T2AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Snipe Air',
        PlatoonTemplate = 'EngineerStateT23RNG',
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
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T2AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH2 },
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Threat Artillery',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 960,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderConditions = {
            { TBC, 'ThreatCloseToBase', {}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 0.9 }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.TECH2 * categories.ARTILLERY}},
        },
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                BaseTemplate = 'DefenseTemplate',
                DesiresAssist = true,
                NumAssistees = 4,
                BuildClose = false,
                maxUnits = 1,
                maxRadius = 35,
                NoPause = true,
                OrderedTemplate = true,
                NearDefensivePoints = true,
                Type = 'Land',
                Tier = 1,
                BuildStructures = {
                    { Unit = 'T2Artillery', Categories = categories.STRUCTURE * categories.ARTILLERY * categories.STRATEGIC * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Defence Single',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 970,
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.DEFENSE * categories.TECH3 * categories.ANTIAIR}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = true,
                NearDefensivePoints = false,
                BuildStructures = {
                    { Unit = 'T3AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH3 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'EngineerStateT3RNG',
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
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T3AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH3 },
                },
                AdjacencyPriority = {categories.STRUCTURE * (categories.SHIELD + categories.FACTORY)},
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Reactive TMD',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'RequireTMDCheckRNG', { 'LocationType' }},
            --{ UCBC, 'LastKnownUnitDetection', { 'LocationType', 'tml'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                NearDefensivePoints = true,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                BuildClose = true,
                NoPause = true,
                Type = 'TMD',
                BuildStructures = {
                    { Unit = 'T2MissileDefense', Categories = categories.STRUCTURE * categories.ANTIMISSILE * categories.DEFENSE * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.TACTICALMISSILEPLATFORM}},
            { UCBC, 'CheckTargetInRangeRNG', { 'LocationType', 'T2StrategicMissile', categories.COMMAND + categories.STRUCTURE * (categories.TECH2 + categories.TECH3) } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.1}},
            --{ EBC, 'GreaterThanEconStorageCurrentRNG', { 400, 4000 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.9}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T2StrategicMissile', Categories = categories.STRUCTURE * categories.STRATEGIC * categories.TACTICALMISSILEPLATFORM * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Base D Engineer AA',
        PlatoonTemplate = 'EngineerStateT3RNG',
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
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                NearDefensivePoints = false,
                maxUnits = 1,
                AdjacencyPriority = {categories.STRUCTURE * (categories.SHIELD + categories.FACTORY)},
                BuildStructures = {
                    { Unit = 'T3AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH3 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim Enemy Walls',
        PlatoonTemplate = 'EngineerReclaimWallsT1RNG',
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
        BuilderName = 'RNGAI T1 Defence High Value Land Expansion',
        PlatoonTemplate = 'EngineerStateT1RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.DEFENSE * categories.DIRECTFIRE}},
            { UCBC, 'HighValueZone', {'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T1GroundDefense', Categories = categories.STRUCTURE * categories.DIRECTFIRE * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Land Expansion',
        PlatoonTemplate = 'EngineerStateT1RNG',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.DEFENSE * categories.DIRECTFIRE}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LAND' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 1, 'LAND'}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T1GroundDefense', Categories = categories.STRUCTURE * categories.DIRECTFIRE * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                    { Unit = 'Wall', Categories = categories.STRUCTURE * categories.WALL * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Air Expansion',
        PlatoonTemplate = 'EngineerStateT1RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 2, categories.DEFENSE * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 1, 'AIR'}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
            BaseTemplate = 'BaseTemplates',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    { Unit = 'T1AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Sea Expansion',
        PlatoonTemplate = 'EngineerStateT1RNG',
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
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                NearDefensivePoints = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY * categories.NAVAL},
                AvoidCategory = categories.STRUCTURE * categories.NAVAL * categories.DEFENSE,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    { Unit = 'T1NavalDefense', Categories = categories.STRUCTURE * categories.ANTINAVY * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Land Expansion',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'LANDNAVAL' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.DIRECTFIRE}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 2, 'LANDNAVAL'}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    { Unit = 'T2GroundDefense', Categories = categories.STRUCTURE * categories.DIRECTFIRE * categories.DEFENSE * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Air Expansion',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtRestrictedRNG', { 'LocationType', 0, 'AIR' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'EnemyThreatGreaterThanPointAtRestrictedRNG', {'LocationType', 2, 'AIR'}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                maxUnits = 1,
                maxRadius = 5,
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    { Unit = 'T2AADefense', Categories = categories.STRUCTURE * categories.ANTIAIR * categories.DEFENSE * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Expansion TML',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer Expansion',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.TACTICALMISSILEPLATFORM}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.0, 1.05}},
            { UCBC, 'CheckTargetInRangeRNG', { 'LocationType', 'T2StrategicMissile', categories.STRUCTURE * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                BuildClose = false,
                NearDefensivePoints = false,
                BuildStructures = {
                    { Unit = 'T2StrategicMissile', Categories = categories.STRUCTURE * categories.STRATEGIC * categories.TACTICALMISSILEPLATFORM * categories.TECH2 }
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Reactive TMD Expansion',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 845,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'RequireTMDCheckRNG', { 'LocationType' }},
            --{ UCBC, 'LastKnownUnitDetection', { 'LocationType', 'tml'}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.7, 0.8}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                NearDefensivePoints = true,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                BuildClose = true,
                NoPause = true,
                Type = 'TMD',
                Tier = 1,
                BuildStructures = {
                    { Unit = 'T2MissileDefense', Categories = categories.STRUCTURE * categories.ANTIMISSILE * categories.DEFENSE * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Artillery Counter',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.9 }},
            { UCBC, 'DefensiveClusterCloseRNG', {'LocationType'}},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 3, categories.STRUCTURE * categories.TECH2 * categories.ARTILLERY}},
        },
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.SHIELD},
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH2,
                maxUnits = 1,
                maxRadius = 35,
                BuildStructures = {
                    { Unit = 'T2Artillery', Categories = categories.STRUCTURE * categories.ARTILLERY * categories.STRATEGIC * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
}


BuilderGroup {
    BuilderGroupName = 'RNGAI T12 Perimeter Defenses Naval',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Sea',
        PlatoonTemplate = 'EngineerStateT123RNG',
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
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T1NavalDefense', Categories = categories.STRUCTURE * categories.ANTINAVY * categories.DEFENSE * categories.TECH1 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Restricted Breach Sea',
        PlatoonTemplate = 'EngineerStateT23RNG',
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
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T2NavalDefense', Categories = categories.STRUCTURE * categories.ANTINAVY * categories.DEFENSE * categories.TECH2 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Restricted Breach Cruisers',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  'BaseRestrictedArea', 'LocationType', 0, categories.MOBILE * categories.NAVAL * categories.CRUISER * (categories.UEF + categories.SERAPHIM) - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 6, categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T2MissileDefense', Categories = categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE }
                },
                LocationType = 'LocationType',
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Defense FormBuilders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T2 TML Silo',
        PlatoonTemplate = 'T2TMLStructureRNG',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 100,
        BuilderConditions = {
            -- Have we the eco to build it ?
            -- When do we want to build this ?
            { UCBC, 'HaveGreaterThanArmyPoolWithCategoryRNG', { 0, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM * categories.TECH2 } },
        },
        BuilderData = {
            StateMachine = 'TML',
            PlatoonPlan = 'TMLAIRNG',
            LocationType = 'LocationType'
        },
        BuilderType = 'Any',
    },
    
    Builder {
        BuilderName = 'RNGAI T2 Artillery',
        PlatoonTemplate = 'T2ArtilleryStructure',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 160,
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
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 } },
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.2, 1.2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.9, 'DEFENSE' } },             -- Ratio from 0 to 1. (1=100%)
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T3StrategicMissileDefense', Categories = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 },
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI SMD Response',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 0.8 }},
            { UCBC, 'HaveUnitRatioVersusEnemyRNG', { 0.50, 'LocationType', 180, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3, '<', categories.SILO * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL) } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
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
                    { Unit = 'T3StrategicMissileDefense', Categories = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 },
                },
                LocationType = 'LocationType',
            }
        }
    },
}