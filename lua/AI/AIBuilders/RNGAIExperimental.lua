local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local ExBaseTmpl = 'ExpansionBaseTemplates'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local ExperimentalDelayWaterMap = function(self, aiBrain, builderManager)
    if aiBrain.MapWaterRatio > 0.60 then
        local enemyX, enemyZ
        if aiBrain:GetCurrentEnemy() then
            enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
            if not enemyX then
                return 910
            end
        else
            return 910
        end

        -- Get the armyindex from the enemy
        local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
        local OwnIndex = aiBrain:GetArmyIndex()
        if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] ~= 'LAND' then
            --RNGLOG('Map ratio is '..aiBrain.MapWaterRatio..' and we cant path to the enemy via land')
            return 0
        end

    end
    return 910
end

local NavalExpansionAdjust = function(self, aiBrain, builderManager)
    if aiBrain.MapWaterRatio < 0.20 and not aiBrain.MassMarkersInWater then
        return 0
    else
        return 500
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Experimental Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Experimental1 1st',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        PriorityFunction = ExperimentalDelayWaterMap,
        Priority = 910,
        DelayEqualBuildPlattons = {'HighValue', 20},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'NOPATH', true } },
            { UCBC, 'IsEngineerNotBuilding', { categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.EXPERIMENTAL * categories.LAND } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 7.5, 250.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 30,
            Construction = {
                DesiresAssist = true,
                BuildClose = true,
                HighValue = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 MultiBuild',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'HighValue', 20},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'NOPATH', true } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.25, 0.95 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.MOBILE }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 30,
            Construction = {
                DesiresAssist = true,
                BuildClose = true,
                HighValue = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Excess',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 300,
        DelayEqualBuildPlattons = {'HighValue', 20},
        InstanceCount = 3,
        BuilderConditions = {
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 4, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.1, 1.2 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.80, 0.95 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                BuildClose = true,
                HighValue = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental1',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Megabot',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 550,
        DelayEqualBuildPlattons = {'HighValue', 20},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 3 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'NOPATH', true } },
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.EXPERIMENTAL * categories.LAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3}},
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 30,
            Construction = {
                DesiresAssist = true,
                BuildClose = false,
                HighValue = true,
                AdjacencyCategory = categories.STRUCTURE * categories.SHIELD,
                BuildStructures = {
                    'T4LandExperimental3',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Air',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 550,
        DelayEqualBuildPlattons = {'HighValue', 20},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            -- Have we the eco to build it ?
            --{ UCBC, 'CanBuildCategoryRNG', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 7.0, 600.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 25,
            Construction = {
                DesiresAssist = true,
                BuildClose = true,
                HighValue = true,
                BuildStructures = {
                    'T4AirExperimental1',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Sea',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 500,
        PriorityFunction = NavalExpansionAdjust,
        DelayEqualBuildPlattons = {'HighValue', 20},
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            -- Have we the eco to build it ?
            --{ UCBC, 'CanBuildCategoryRNG', { categories.MOBILE * categories.AIR * categories.EXPERIMENTAL - categories.SATELLITE } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 7.0, 600.0 }},                    -- Base income
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 15,
            Construction = {
                DesiresAssist = true,
                BuildClose = true,
                HighValue = true,
                BuildStructures = {
                    'T4SeaExperimental1',
                },
                LocationType = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Experimental1 Novax',
        PlatoonTemplate = 'T3SACUEngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'HighValue', 20},
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 1 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { UCBC, 'ValidateLateGameBuild', { 'LocationType' }},
            -- Have we the eco to build it ?
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 1.05, 1.05 }},
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } },
            { EBC, 'GreaterThanEconIncomeCombinedRNG', { 7.0, 600.0 }},                    -- Base income
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.EXPERIMENTAL}},
        },
        BuilderType = 'Any',
        BuilderData = {
            JobType = 'BuildStructure',
            NumAssistees = 10,
            Construction = {
                DesiresAssist = true,
                BuildClose = true,
                HighValue = true,
                BuildStructures = {
                    'T4SatelliteExperimental',
                },
                LocationType = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Experimental Formers',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T4 Exp Land',
        PlatoonTemplate = 'T4ExperimentalLandRNG',
        Priority = 1000,
        FormRadius = 10000,
        InstanceCount = 50,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.EXPERIMENTAL } },
        },
        BuilderType = 'Any',
        BuilderData = {
            ThreatWeights = {
                TargetThreatType = 'Commander',
            },
            UseMoveOrder = true,
            LocationType = 'LocationType',
            PrioritizedCategories = { 'EXPERIMENTAL LAND', 'COMMAND', 'FACTORY LAND', 'MASSPRODUCTION', 'ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE' },
        },
    },
    Builder {
        BuilderName = 'RNGAI T4 Exp Air',
        PlatoonTemplate = 'T4ExperimentalAirRNG',
        Priority = 1000,
        FormRadius = 10000,
        InstanceCount = 50,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.AIR * categories.EXPERIMENTAL } },
        },
        BuilderType = 'Any',
        BuilderData = {
            ThreatWeights = {
                TargetThreatType = 'Commander',
            },
            UseMoveOrder = true,
            PrioritizedCategories = { 'EXPERIMENTAL LAND', 'COMMAND', 'FACTORY LAND', 'MASSPRODUCTION', 'ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE' },
        },
    },
    Builder {
        BuilderName = 'RNGAI T4 Exp Sea',
        PlatoonTemplate = 'T4ExperimentalSea',
        Priority = 1000,
        FormRadius = 10000,
        InstanceCount = 50,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.NAVAL * categories.EXPERIMENTAL } },
        },
        BuilderType = 'Any',
        BuilderData = {
            ThreatWeights = {
                TargetThreatType = 'Commander',
            },
            UseMoveOrder = true,
            PrioritizedCategories = { 'EXPERIMENTAL LAND', 'COMMAND', 'FACTORY NAVAL', 'MASSPRODUCTION', 'ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE' },
        },
    },
    Builder {
        BuilderName = 'RNGAI T4 Exp Satellite',
        PlatoonTemplate = 'T4SatelliteExperimentalRNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.STRUCTURE * categories.EXPERIMENTAL * categories.ORBITALSYSTEM } },
        },
        FormRadius = 250,
        InstanceCount = 50,
        BuilderType = 'Any',
        BuilderData = {
            SearchRadius = 6000,
            UnitType = 'SATELLITE',
            PrioritizedCategories = { 
                categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH3, 
                categories.MASSEXTRACTION * categories.STRUCTURE * categories.TECH3,
                categories.MASSEXTRACTION * categories.STRUCTURE * categories.TECH2, 
                categories.MASSEXTRACTION * categories.STRUCTURE, 
                categories.STRUCTURE * categories.STRATEGIC * categories.EXPERIMENTAL, 
                categories.EXPERIMENTAL * categories.ARTILLERY * categories.OVERLAYINDIRECTFIRE, 
                categories.STRUCTURE * categories.STRATEGIC * categories.TECH3, 
                categories.STRUCTURE * categories.NUKE * categories.TECH3, 
                categories.EXPERIMENTAL * categories.ORBITALSYSTEM, 
                categories.EXPERIMENTAL * categories.ENERGYPRODUCTION * categories.STRUCTURE, 
                categories.TECH3 * categories.MASSFABRICATION, 
                categories.TECH3 * categories.ENERGYPRODUCTION, 
                categories.STRUCTURE * categories.STRATEGIC, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.ANTIAIR, 
                categories.COMMAND, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.DIRECTFIRE, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.SHIELD, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH2, 
                categories.STRUCTURE,
            },
        },
    },
}
