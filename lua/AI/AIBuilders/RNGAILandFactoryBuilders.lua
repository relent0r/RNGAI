local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T1',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Scout',
        PlatoonTemplate = 'T1LandScout',
        --UnitCategory = categories.LAND * categories.SCOUT,
        Priority = 755,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'scout'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Tank',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 745,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'tank'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 745,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'arty'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery Demand',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 746,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T1', 'arty'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 AA',
        PlatoonTemplate = 'T1LandAA',
        Priority = 743,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'aa'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 AA Demand',
        PlatoonTemplate = 'T1LandAA',
        Priority = 746,
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', {'LocationType', 'MAIN' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T1', 'aa'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T2 MobileBomb',
        PlatoonTemplate = 'T2MobileBombs',
        Priority = 891,
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T2', 'mobilebomb'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Tank',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'tank'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Bot',
        PlatoonTemplate = 'RNGAIT2AttackBot',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'bot'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Bot Demand',
        PlatoonTemplate = 'RNGAIT2AttackBot',
        Priority = 751,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T2', 'bot'} },
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'bot'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 AA',
        PlatoonTemplate = 'T2LandAA',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'aa'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 AA Demand',
        PlatoonTemplate = 'T2LandAA',
        Priority = 751,
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T2', 'aa'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield',
        PlatoonTemplate = 'T2MobileShields',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'shield'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield Demand',
        PlatoonTemplate = 'T2MobileShields',
        Priority = 755,
        BuilderConditions = {
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T2', 'shield'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 MML Demand',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 751,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T2', 'mml'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile Stealth',
        PlatoonTemplate = 'RNGAIT2MobileStealth',
        Priority = 746,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'stealth'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Amphib Demand',
        PlatoonTemplate = 'T2LandAmphibious',
        Priority = 751,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T2', 'amphib'} },
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T3',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Tank',
        PlatoonTemplate = 'T3LandBot',
        Priority = 755,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'tank'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
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
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'armoured'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 AA',
        PlatoonTemplate = 'T3LandAA',
        Priority = 753,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'aa'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 AA Demand',
        PlatoonTemplate = 'T3LandAA',
        Priority = 756,
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocationRNG', { 'LocationType', 'MAIN' } },
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T3', 'aa'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery Demand',
        PlatoonTemplate = 'T3LandArtillery',
        Priority = 756,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T3', 'arty'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Shields',
        PlatoonTemplate = 'T3MobileShields',
        Priority = 755,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'shield'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Sniper',
        PlatoonTemplate = 'T3SniperBots',
        Priority = 755,
        BuilderConditions = {
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'LAND' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'sniper'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Sniper Demand',
        PlatoonTemplate = 'T3SniperBots',
        Priority = 756,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T3', 'sniper'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading', nil, true}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Missile Demand',
        PlatoonTemplate = 'T3MobileMissile',
        Priority = 756,
        BuilderConditions = {
            { UCBC, 'UnitBuildDemand', {'LocationType', 'Land', 'T3', 'mml'} },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T1 Islands',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Scout Islands',
        PlatoonTemplate = 'T1LandScout',
        Priority = 744,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }},
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'scout'} },
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Tank Islands',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }},
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.20}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery Islands',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 4 }},
            { MIBC, 'PathCheckToCurrentEnemyRNG', { 'LocationType', 'AMPHIBIOUS' } },
            { EBC, 'FactorySpendRatioRNG', {'Land', 'LandUpgrading'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.20}},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * categories.TECH2 }},
            { UCBC, 'UnitCapCheckLess', { .85 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
}

