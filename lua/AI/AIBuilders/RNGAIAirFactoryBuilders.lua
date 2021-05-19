local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

local AirMode = function(self, aiBrain, builderManager, builderData)
    --LOG('Setting T1 Queue to Eng')
    if builderData.TechLevel == 1 then
        return 745
    elseif builderData.TechLevel == 2 then
        return 750
    elseif builderData.TechLevel == 3 then
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
        Priority = 744, -- After second engie group
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'scout'} },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI T1 Air Interceptor',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 745,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'interceptor'} },
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
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'bomber'} },
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
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T1', 'gunship'} },
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
        Priority = 750,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T2', 'bomber'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'AIR'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.75, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Gunship',
        PlatoonTemplate = 'T2AirGunship',
        Priority = 748,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T2', 'gunship'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'AIR'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.75, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Fighter',
        PlatoonTemplate = 'T2FighterBomber',
        Priority = 749,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T2', 'fighter'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'AIR'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.75, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Torperdo Bomber',
        PlatoonTemplate = 'T2AirTorpedoBomber',
        Priority = 747,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T2', 'torpedo'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'AIR'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.75, 0.8 }},
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
        Priority = 746,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Air', 'T2', 'mercy'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'AIR'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.75, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Air',
        BuilderData = {
            TechLevel = 2
        },
    },
}
--[[
BuilderGroup {
    BuilderGroupName = 'RNGAI AirBuilder T3 Ratio',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Tank',
        PlatoonTemplate = 'T3LandBot',
        Priority = 755,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'tank'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Armoured',
        PlatoonTemplate = 'T3ArmoredAssault',
        Priority = 755,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'armoured'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 AA',
        PlatoonTemplate = 'T3LandAA',
        Priority = 752,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'aa'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery',
        PlatoonTemplate = 'T3LandArtillery',
        Priority = 753,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'arty'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Shields',
        PlatoonTemplate = 'T3MobileShields',
        Priority = 751,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'shield'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Sniper',
        PlatoonTemplate = 'T3SniperBots',
        Priority = 754,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'sniper'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Missile',
        PlatoonTemplate = 'T3MobileMissile',
        Priority = 754,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'mml'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.02, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
}

]]