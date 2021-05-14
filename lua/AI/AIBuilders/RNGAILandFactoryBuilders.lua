local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

local LandMode = function(self, aiBrain, builderManager, builderData)
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
    BuilderGroupName = 'RNGAI LandBuilder T1',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 744, -- After second engie group
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'scout'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Tank',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 745,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'tank'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 743,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'arty'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 AA',
        PlatoonTemplate = 'T1LandAA',
        Priority = 742,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'aa'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
        BuilderName = 'RNGAI T2 Tank',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 750,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'tank'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Bot',
        PlatoonTemplate = 'RNGAIT2AttackBot',
        Priority = 749,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'bot'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 AA',
        PlatoonTemplate = 'T2LandAA',
        Priority = 746,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'aa'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield',
        PlatoonTemplate = 'T2MobileShields',
        Priority = 747,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'shield'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 MML',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 748,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'mml'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
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
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'stealth'} },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.03, 0.1, 'LAND'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
}

