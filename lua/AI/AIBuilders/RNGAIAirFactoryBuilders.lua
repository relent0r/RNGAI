local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local AirMode = function(self, aiBrain, builderManager, builderData)
    --RNGLOG('Setting T1 Queue to Eng')
    if builderData.BuilderData.TechLevel == 1 then
        return 745
    elseif builderData.BuilderData.TechLevel == 2 then
        return 750
    elseif builderData.BuilderData.TechLevel == 3 then
        return 755
    end
    return 0
end

local T3BomberRushActivated = function(self, aiBrain, builderManager)
    --RNGLOG('LocationType is '..builderManager.LocationType)
    if aiBrain.IntelManager.StrategyFlags.T3BomberRushActivated then
        --LOG('Shield response has been triggered')
        return 890
    else
        return 896
    end
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T1 Ratio',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Scout Demand',
        PlatoonTemplate = 'T1AirScout',
        Priority = 750, -- After second engie group
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T1', 'scout'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Interceptor',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 750,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'interceptor'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading'}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Bomber',
        PlatoonTemplate = 'T1AirBomber',
        Priority = 743,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'bomber'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading'}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Gunship Demand',
        PlatoonTemplate = 'T1Gunship',
        Priority = 881,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType','Air', 'T1', 'gunship'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Transport Demand',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType','Air', 'T1', 'transport'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 1
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T2 Ratio',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T2 FighterBomber',
        PlatoonTemplate = 'T2FighterBomber',
        Priority = 891,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType','Air', 'T2', 'bomber'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Mercy',
        PlatoonTemplate = 'T2AirMissile',
        Priority = 895,
        BuilderType = 'Air',
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'UnitBuildDemand', {'LocationType','Air', 'T2', 'mercy'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Torp Bomber',
        PlatoonTemplate = 'T2AirTorpedoBomber',
        Priority = 893,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T2', 'torpedo'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T2 Gunship',
        PlatoonTemplate = 'T2AirGunship',
        Priority = 889,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T2', 'gunship'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T3 Ratio',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Scout',
        PlatoonTemplate = 'T3AirScout',
        Priority = 755,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T3', 'scout'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 ASF',
        PlatoonTemplate = 'T3AirFighter',
        Priority = 755,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T3', 'asf'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading'}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Bomber',
        PlatoonTemplate = 'T3AirBomber',
        Priority = 896,
        PriorityFunction = T3BomberRushActivated,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T3', 'bomber'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Gunship',
        PlatoonTemplate = 'T3AirGunship',
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T3', 'gunship'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Torp Bomber',
        PlatoonTemplate = 'T3TorpedoBomber',
        Priority = 891,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Air', 'T3', 'torpedo'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Transport',
        PlatoonTemplate = 'T3AirTransport',
        Priority = 752,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T3', 'transport'} },
            { EBC, 'FactorySpendRatioRNG', {'LocationType', 'Air', 'AirUpgrading'}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
}
