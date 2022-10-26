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

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T1 Ratio',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Scout',
        PlatoonTemplate = 'T1AirScout',
        Priority = 750, -- After second engie group
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', { 'Air', 'T1', 'scout'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Interceptor',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 750,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'interceptor'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Gunship',
        PlatoonTemplate = 'T1Gunship',
        Priority = 742,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'gunship'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { UCBC, 'UnitBuildDemand', {'Air', 'T2', 'bomber'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { UCBC, 'UnitBuildDemand', {'Air', 'T2', 'mercy'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Torp Bomber',
        PlatoonTemplate = 'T2AirTorpedoBomber',
        Priority = 890,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', { 'Air', 'T2', 'torpedo'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
    },
    --[[
    Builder {
        BuilderName = 'RNGAI T2 Gunship',
        PlatoonTemplate = 'T2AirGunship',
        Priority = 748,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T2', 'gunship'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },]]
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T3 Ratio',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Scout',
        PlatoonTemplate = 'T3AirScout',
        Priority = 755,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', { 'Air', 'T3', 'scout'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Bomber',
        PlatoonTemplate = 'T3AirBomber',
        Priority = 754,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T3', 'bomber'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Gunship',
        PlatoonTemplate = 'T3AirGunship',
        Priority = 753,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T3', 'gunship'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { UCBC, 'UnitBuildDemand', { 'Air', 'T2', 'torpedo'} },
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
            { EBC, 'FactorySpendRatioRNG', {'Air'}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 3
        },
    },
}
