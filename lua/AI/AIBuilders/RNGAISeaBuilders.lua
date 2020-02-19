local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

BuilderGroup {
    BuilderGroupName = 'RNGAI Sea Builders',                               
    BuildersType = 'FactoryBuilder',
    -- TECH 1
    Builder {
        BuilderName = 'RNGAI Sea T1 Sub Response',
        PlatoonTemplate = 'T1SeaSub',
        Priority = 18600,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL }}, -- radius, LocationType, unitCount, categoryEnemy
            -- Do we need additional conditions to build it ?
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 40,  categories.MOBILE * categories.NAVAL } },
            -- Have we the eco to build it ?
            -- Don't build it if...
            { UCBC, 'UnitsGreaterAtEnemy', { 2 , categories.NAVAL * categories.FACTORY } },
        },
        BuilderType = 'Sea',
    },
    Builder {
        BuilderName = 'RNGAI Sea T1 Frig Response',
        PlatoonTemplate = 'T1SeaAntiAir',
        Priority = 18500,
        BuilderConditions = {
            -- When do we want to build this ?
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR * ( categories.BOMBER + categories.GROUNDATTACK + categories.ANTINAVY ) }}, -- radius, LocationType, unitCount, categoryEnemy
            -- Do we need additional conditions to build it ?
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 40,  categories.MOBILE * categories.NAVAL } },
            -- Have we the eco to build it ?
            -- Don't build it if...
            { UCBC, 'UnitsGreaterAtEnemy', { 2 , categories.NAVAL * categories.FACTORY } },
        },
        BuilderType = 'Sea',
    },
}