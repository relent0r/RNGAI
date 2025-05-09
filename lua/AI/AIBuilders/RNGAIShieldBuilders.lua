local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local ActiveExpansion = function(self, aiBrain, builderManager)
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --RNGLOG('Active Expansion is set'..builderManager.LocationType)
        --RNGLOG('Active Expansion builders are set to 900')
        return 700
    else
        --RNGLOG('Disable Air Intie Pool Builder')
        --RNGLOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end

local ShieldResponse = function(self, aiBrain, builderManager)
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.emanager.Artillery.T3 > 0 or aiBrain.emanager.Artillery.T4 > 0 or aiBrain.emanager.Satellite.T4 > 0 then
        --LOG('Shield response has been triggered')
        return 950
    else
        return 0
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Shield Builder',                   
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Shield Single',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Shield', 5},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                DesiresAssist = true,
                NumAssistees = 4,
                BuildClose = false,
                AdjacencyPriority = {categories.ENERGYPRODUCTION * categories.TECH2,categories.STRUCTURE * categories.FACTORY},
                AvoidCategory = categories.STRUCTURE * categories.SHIELD,
                maxUnits = 1,
                maxRadius = 35,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2ShieldDefense', Categories = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE * categories.TECH2 },
                },
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield DefensivePoint',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 700,
        DelayEqualBuildPlattons = {'Shield', 5},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'DefensivePointShieldRequired', { 'LocationType' }},
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.8, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                BaseTemplate = 'DefenseTemplate',
                DesiresAssist = true,
                NumAssistees = 4,
                NoPause = true,
                BuildClose = false,
                OrderedTemplate = true,
                NearDefensivePoints = true,
                Type = 'SHIELD',
                Tier = 2,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2ShieldDefense', Categories = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE * categories.TECH2 },
                },
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield Ratio',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 625,
        DelayEqualBuildPlattons = {'Shield', 5},
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'HaveUnitRatioAtLocationRNG', { 'LocationType', 1.0, categories.STRUCTURE * categories.SHIELD, '<=',categories.STRUCTURE * categories.TECH3 * (categories.ENERGYPRODUCTION + categories.FACTORY) } },
            { MIBC, 'FactionIndex', { 1, 3, 4 }}, -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads 
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.95 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.95, 1.1 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'HaveUnitRatioVersusCapRNG', { 0.12 / 2, '<', categories.STRUCTURE * categories.DEFENSE * categories.SHIELD } },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 8,
            Construction = {
                UseShieldTable = false,
                UseBaseTable = true,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                DesiresAssist = true,
                BuildClose = false,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2ShieldDefense', Categories = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE * categories.TECH2 },
                },
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Shield Ratio',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 650,
        DelayEqualBuildPlattons = {'Shield', 5},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.95 } },
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.95, 1.1 }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'HaveUnitRatioAtLocationRNG', { 'LocationType', 1.0, categories.STRUCTURE * categories.SHIELD, '<=',categories.STRUCTURE * categories.TECH3 * (categories.ENERGYPRODUCTION + categories.FACTORY) } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3) } },
            { UCBC, 'HaveUnitRatioVersusCapRNG', { 0.12 / 2, '<', categories.STRUCTURE * categories.DEFENSE * categories.SHIELD } },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 8,
            Construction = {
                UseShieldTable = false,
                UseBaseTable = true,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                DesiresAssist = true,
                BuildClose = false,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T3ShieldDefense', Categories = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE * categories.TECH3 },
                },
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI Shield Response',
        PlatoonTemplate = 'EngineerStateT3RNG',
        Priority = 0,
        PriorityFunction = ShieldResponse,
        DelayEqualBuildPlattons = {'Shield', 5},
        InstanceCount = 2,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.0 }},
            { UCBC, 'CheckBaseShieldsRequired', { 'LocationType' }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 8,
            Construction = {
                UseShieldTable = false,
                UseBaseTable = true,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                DesiresAssist = true,
                BuildClose = false,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T3ShieldDefense', Categories = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE * categories.TECH3 },
                },
            },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Shield Builder Expansion',                   
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Shield Single Expansion Active',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        DelayEqualBuildPlattons = {'Shield', 5},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.0 }},
            { UCBC, 'IsEngineerNotBuilding', { categories.STRUCTURE * categories.SHIELD}},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3)} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 8,
            Construction = {
                DesiresAssist = true,
                BuildClose = false,
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY},
                AvoidCategory = categories.STRUCTURE * categories.SHIELD,
                maxUnits = 1,
                maxRadius = 35,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2ShieldDefense', Categories = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE * categories.TECH2 },
                },
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield Expansion Response',
        PlatoonTemplate = 'EngineerStateT23RNG',
        Priority = 0,
        PriorityFunction = ShieldResponse,
        DelayEqualBuildPlattons = {'Shield', 5},
        InstanceCount = 1,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyCombinedRNG', { 0.9, 1.0 }},
            { UCBC, 'CheckBaseShieldsRequired', { 'LocationType' }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 1, categories.STRUCTURE * categories.SHIELD * (categories.TECH2 + categories.TECH3)} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'BuildStructure',
            NumAssistees = 8,
            Construction = {
                DesiresAssist = true,
                BuildClose = false,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua',
                BaseTemplate = 'BaseTemplates',
                AdjacencyPriority = {categories.STRUCTURE * categories.FACTORY},
                AvoidCategory = categories.STRUCTURE * categories.SHIELD,
                maxUnits = 1,
                maxRadius = 35,
                LocationType = 'LocationType',
                BuildStructures = {
                    { Unit = 'T2ShieldDefense', Categories = categories.DEFENSE * categories.SHIELD * categories.STRUCTURE * categories.TECH2 },
                },
            },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Shields Upgrader',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI Shield Cybran 1',
        PlatoonTemplate = 'T2Shield1',
        Priority = 700,
        DelayEqualBuildPlattons = {'ShieldUpgrade', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.9}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.SHIELD }},
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield Cybran 2',
        PlatoonTemplate = 'T2Shield2',
        Priority = 700,
        DelayEqualBuildPlattons = {'ShieldUpgrade', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.9}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.SHIELD }},
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield Cybran 3',
        PlatoonTemplate = 'T2Shield3',
        Priority = 700,
        DelayEqualBuildPlattons = {'ShieldUpgrade', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.9}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 0, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.SHIELD }},
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield Cybran 4',
        PlatoonTemplate = 'T2Shield4',
        Priority = 700,
        DelayEqualBuildPlattons = {'ShieldUpgrade', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.9 } },             -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.SHIELD }},
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI Shield UEF Seraphim',
        PlatoonTemplate = 'T2Shield',
        Priority = 700,
        DelayEqualBuildPlattons = {'ShieldUpgrade', 2},
        InstanceCount = 5,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.9 } },             -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendCombinedRNG', { 0.0, 0.0 } }, -- relative income
            { UCBC, 'UnitsGreaterAtLocation', { 'LocationType', 1, categories.TECH3 * categories.ENERGYPRODUCTION}},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingUpgradedRNG', { 2, categories.STRUCTURE * categories.SHIELD }},
            -- { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Shield' }},
        },
        BuilderType = 'Any',
    },
}