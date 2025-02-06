--[[
    File    :   /lua/AI/AIBuilders/RNGAIExpansionBuilders.lua
    Author  :   relentless
    Summary :
        Expansion Base Templates
]]

local ExBaseTmpl = 'ExpansionBaseTemplates'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local NavalExpansionAdjust = function(self, aiBrain, builderManager)
    local currentEnemy = aiBrain:GetCurrentEnemy()
    if not currentEnemy then
        return 0
    end
    local validAttackPriorityModifier = 0
    if aiBrain.BrainIntel.NavalBaseLabels then
        for _, v in aiBrain.BrainIntel.NavalBaseLabels do
            if v == 'Confirmed' then
                validAttackPriorityModifier = validAttackPriorityModifier + 100
            end
        end
    end
    if aiBrain.EnemyIntel.NavalValue then
        if aiBrain.EnemyIntel.NavalValue > 400 then
            validAttackPriorityModifier = validAttackPriorityModifier + 100
        end
    end
    if aiBrain.BrainIntel.PlayerRole.AirPlayer then
        return 0
    elseif aiBrain.BrainIntel.PlayerRole.NavalPlayer then
        return 1000
    elseif aiBrain.MapWaterRatio < 0.20 and not aiBrain.MassMarkersInWater then
        --RNGLOG('NavalExpansionAdjust return 0')
        return 0
    elseif aiBrain.MapWaterRatio < 0.30 then
        local priority = 200
        local EnemyIndex = currentEnemy:GetArmyIndex()
        local OwnIndex = aiBrain:GetArmyIndex()
        if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] ~= 'LAND' then
            priority = priority + 200
        end
        priority = priority + validAttackPriorityModifier
        priority = math.min(priority,1000)
        --LOG('NavalExpansionAdjust return '..tostring(priority)..' ,map water ratio is '..tostring(aiBrain.MapWaterRatio))
        return priority
    elseif aiBrain.MapWaterRatio < 0.40 then
        local priority = 400
        local EnemyIndex = currentEnemy:GetArmyIndex()
        local OwnIndex = aiBrain:GetArmyIndex()
        if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] ~= 'LAND' then
            priority = priority + 200
        end
        priority = priority + validAttackPriorityModifier
        priority = math.min(priority,1000)
        --LOG('NavalExpansionAdjust return '..tostring(priority))
        return priority
    elseif aiBrain.MapWaterRatio < 0.60 then
        local priority = 675
        local EnemyIndex = currentEnemy:GetArmyIndex()
        local OwnIndex = aiBrain:GetArmyIndex()
        if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] ~= 'LAND' then
            priority = priority + 200
        end
        priority = priority + validAttackPriorityModifier
        priority = math.min(priority,1000)
        --LOG('NavalExpansionAdjust return '..tostring(priority))
        return priority
    else
        local priority = 950
        local EnemyIndex = currentEnemy:GetArmyIndex()
        local OwnIndex = aiBrain:GetArmyIndex()
        if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] ~= 'LAND' then
            priority = priority + 200
        end
        priority = priority + validAttackPriorityModifier
        priority = math.min(priority,1000)
        --LOG('NavalExpansionAdjust return '..tostring(priority))
        return priority
    end
end

local FrigateRaid = function(self, aiBrain, builderManager)
    -- Will return the rush naval build if it can raid mexes
    if aiBrain.EnemyIntel.FrigateRaid and not aiBrain.BrainIntel.PlayerRole.AirPlayer then
        --RNGLOG('Frigate Raid priority function is 995')
        --LOG('Returning Naval Frigate Raid Expansion Priority of 1000')
        return 1000
    end
    --RNGLOG('Frigate Raid priority function is 0')
    return 0
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Zone Expansion Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Zone Expansion Primary',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 997,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DisableOnStrategy', { {'T3AirRush'} }},
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'ZoneAvailableRNG', { 'LocationType' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'Expansion',
            TransportWait = 10,
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                ZoneExpansion = true,
                NearMarkerType = 'Zone Expansion',
                ExpansionRadius = 120, -- Defines the radius of the builder managers to avoid them intruding on another base if the expansion marker is too close
                LocationRadius = 1000,
                LocationType = 'LocationType',
                BuildStructures = {                    
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI Zone Expansion',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 995,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DisableOnStrategy', { {'T3AirRush'} }},
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'ZoneAvailableRNG', { 'LocationType' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'Expansion',
            TransportWait = 5,
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                ZoneExpansion = true,
                NearMarkerType = 'Zone Expansion',
                ExpansionRadius = 120, -- Defines the radius of the builder managers to avoid them intruding on another base if the expansion marker is too close
                LocationRadius = 1000,
                LocationType = 'LocationType',
                BuildStructures = {                    
                    { Unit = 'T1LandFactory', Categories = categories.FACTORY * categories.LAND * categories.TECH1 },
                }
            },
            NeedGuard = true,
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Naval Expansion Builders Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area FrigateRaid',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 0,
        PriorityFunction = FrigateRaid,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DisableOnStrategy', { {'T3AirRush'} }},
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL } },
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', false, 250, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'Expansion',
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 70,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area 250 Small',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 740,
        PriorityFunction = NavalExpansionAdjust,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DisableOnStrategy', { {'T3AirRush'} }},
            { UCBC, 'NavalBaseLimitRNG', { 2 } }, -- Forces limit to the number of naval expansions
            { UCBC, 'ExistingNavalExpansionFactoryGreaterRNG', { 3,  categories.FACTORY * categories.STRUCTURE }},
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', true, 250, -1000, 100, 1, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.0}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'Expansion',
            TransportWait = 5,
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ValidateLabel = true,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 70,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                }
            },
            NeedGuard = false,
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Naval Expansion Builders Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area FrigateRaid Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        Priority = 0,
        PriorityFunction = FrigateRaid,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DisableOnStrategy', { {'T3AirRush'} }},
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LessThanFactoryCountRNG', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL } },
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', false, 250, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'Expansion',
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 70,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area 650 Large',
        PlatoonTemplate = 'EngineerStateT123RNG',
        PriorityFunction = NavalExpansionAdjust,
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'DisableOnStrategy', { {'T3AirRush'} }},
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'NavalBaseLimitRNG', { 3 } }, -- Forces limit to the number of naval expansions
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', true, 650, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'ExistingNavalExpansionFactoryGreaterRNG', { 3, categories.FACTORY * categories.STRUCTURE }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.0}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            StateMachine = 'EngineerBuilder',
            JobType = 'Expansion',
            TransportWait = 5,
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ValidateLabel = true,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 60,
                LocationRadius = 650, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    { Unit = 'T1SeaFactory', Categories = categories.FACTORY * categories.NAVAL * categories.TECH1 },
                    { Unit = 'T1NavalDefense', Categories = categories.DEFENSE * categories.ANTINAVY * categories.TECH1 * categories.STRUCTURE },
                }
            },
            NeedGuard = false,
        }
    },
}