local AIBasePlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

---@class AIPlatoon : moho.platoon_methods
---@field BuilderData table
---@field Units Unit[]
---@field Brain moho.aibrain_methods
---@field Trash TrashBag
AIPlatoonRNG = Class(AIBasePlatoon) {

    PlatoonName = 'PlatoonBaseRNG',
    StateName = 'Unknown',

    ---@param self AIPlatoon
    OnDestroy = function(self)
        if self.BuilderHandle then
            self.BuilderHandle:RemoveHandle(self)
        end
        self.Trash:Destroy()
    end,

    ---@param self AIPlatoon
    OnUnitsAddedToPlatoon = function(self)
        local units = self:GetPlatoonUnits()
        self.Units = units
        local maxPlatoonStrikeDamage = 0
        local maxPlatoonDPS = 0
        local maxPlatoonStrikeRadius = 20
        local maxPlatoonStrikeRadiusDistance = 0
        local intelrange = 0
        for k, unit in units do
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            unit.AIPlatoonReference = self
            local unitBp = unit.Blueprint
            local unitCats = unit.Blueprint.CategoriesHash
            if self.Debug then
                unit:SetCustomName(self.PlatoonName)
            end
            if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                unit:SetScriptBit('RULEUTC_StealthToggle', false)
            end
            if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                unit:SetScriptBit('RULEUTC_CloakToggle', false)
            end
            if unitBp.Weapon then
                if unitCats.BOMBER then
                    for _, weapon in unitBp.Weapon or {} do
                        if (weapon.WeaponCategory == 'Bomb' or weapon.RangeCategory == 'UWRC_DirectFire') then
                            unit['rngdata'].DamageRadius = weapon.DamageRadius
                            unit['rngdata'].StrikeDamage = weapon.Damage * weapon.MuzzleSalvoSize
                            if weapon.InitialDamage then
                                unit['rngdata'].StrikeDamage = unit['rngdata'].StrikeDamage + (weapon.InitialDamage * weapon.MuzzleSalvoSize)
                            end
                            unit['rngdata'].StrikeRadiusDistance = weapon.MaxRadius
                            maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + unit['rngdata'].StrikeDamage
                            --LOG('Bomber Weapon radius is '..repr(weapon.DamageRadius))
                            if weapon.DamageRadius > 0 or  weapon.DamageRadius < maxPlatoonStrikeRadius then
                                maxPlatoonStrikeRadius = weapon.DamageRadius
                            end
                            if unit['rngdata'].StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                                maxPlatoonStrikeRadiusDistance = unit['rngdata'].StrikeRadiusDistance
                            end
                        elseif weapon.WeaponCategory == 'Anti Navy' and unitCats.AIR then
                            unit['rngdata'].DamageRadius = weapon.DamageRadius
                            unit['rngdata'].StrikeDamage = weapon.Damage * weapon.MuzzleSalvoSize
                            if weapon.InitialDamage then
                                unit['rngdata'].StrikeDamage = unit['rngdata'].StrikeDamage + (weapon.InitialDamage * weapon.MuzzleSalvoSize)
                            end
                            unit['rngdata'].StrikeRadiusDistance = weapon.MaxRadius
                            maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + unit['rngdata'].StrikeDamage
                            --LOG('Torp Bomber Weapon radius is '..repr(weapon.DamageRadius))
                            if weapon.DamageRadius > 0 or  weapon.DamageRadius < maxPlatoonStrikeRadius then
                                maxPlatoonStrikeRadius = weapon.DamageRadius
                            end
                            if unit['rngdata'].StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                                maxPlatoonStrikeRadiusDistance = unit['rngdata'].StrikeRadiusDistance
                            end
                        end
                    end
                    --LOG('Have set units DamageRadius to '..maxPlatoonStrikeRadius)
                end
                if unitCats.GUNSHIP and not unit['rngdata'].ApproxDPS then
                    for _, weapon in unitBp.Weapon or {} do
                        if not weapon.CannotAttackGround and weapon.RangeCategory == 'UWRC_DirectFire' then
                            unit['rngdata'].ApproxDPS = RUtils.CalculatedDPSRNG(weapon) --weaponBlueprint.RateOfFire * (weaponBlueprint.MuzzleSalvoSize or 1) *  weaponBlueprint.Damage
                            maxPlatoonDPS = maxPlatoonDPS + unit['rngdata'].ApproxDPS
                        end
                    end
                end
                if not unit['rngdata'].MaxWeaponRange and unitBp.Weapon[1].MaxRadius and not unitBp.Weapon[1].ManualFire then
                    unit['rngdata'].MaxWeaponRange = unitBp.Weapon[1].MaxRadius
                end
                if not unit['rngdata'].MaxWeaponRange then
                    for _, weapon in unitBp.Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if weapon.WeaponCategory == 'Anti Air' then
                            continue
                        end
                        if not unit['rngdata'].MaxWeaponRange or weapon.MaxRadius > unit['rngdata'].MaxWeaponRange then
                            -- save the weaponrange 
                            unit['rngdata'].MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                unit['rngdata'].WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                unit['rngdata'].WeaponArc = 'high'
                            else
                                unit['rngdata'].WeaponArc = 'none'
                            end
                        end
                    end
                end
                if unit['rngdata'].MaxWeaponRange and (unitBp.Weapon and unitBp.Weapon[1].RangeCategory == 'UWRC_DirectFire' and not self.MaxDirectFireRange or self.MaxDirectFireRange < unit['rngdata'].MaxWeaponRange) and not unitCats.SCOUT then
                    self.MaxDirectFireRange = unit['rngdata'].MaxWeaponRange
                end
                if unit['rngdata'].MaxWeaponRange and (not self.MaxPlatoonWeaponRange or self.MaxPlatoonWeaponRange < unit['rngdata'].MaxWeaponRange) then
                    self.MaxPlatoonWeaponRange = unit['rngdata'].MaxWeaponRange
                end
            end
            if not unit['rngdata'].MaxWeaponRange then
                unit['rngdata'].MaxWeaponRange = 0
            end
            if unitCats.SATELLITE then
                if not self.NovaxUnits then
                    self.NovaxUnits = {}
                end
                if not self.NovaxUnits[unit.EntityId] then
                    self.NovaxUnits[unit.EntityId] = {Unit = unit, CurrentTarget = nil, CurrentTargetHealth = nil }
                end
            end
            if unitCats.ARTILLERY and ( unitCats.STRUCTURE and unitCats.TECH3 or unitCats.EXPERIMENTAL ) then
                if unit.Blueprint.Weapon[1].MaxRadius > self.MaxPlatoonWeaponRange then
                    self.MaxPlatoonWeaponRange = unit.Blueprint.Weapon[1].MaxRadius
                end
                if not self.ArtilleryUnits then
                    self.ArtilleryUnits = {}
                end
                if not self.ArtilleryUnits[unit.EntityId] then
                    self.ArtilleryUnits[unit.EntityId] = {Unit = unit, CurrentTarget = nil }
                end
            end
            if unitCats.TACTICALMISSILEPLATFORM and unitCats.STRUCTURE and unitCats.TECH2 then
                if not unit['rngdata'].terraincallbackset then
                    local missileTerrainCallbackRNG = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua').MissileCallbackRNG
                    unit:AddMissileImpactTerrainCallback(missileTerrainCallbackRNG)
                    unit['rngdata'].terraincallbackset = true
                end
                unit:SetAutoMode(true)
                IssueClearCommands({unit})
            end
            if (unit.Sync.Regen>0) or not unit.initialized then
                unit.initialized=true
                if unitCats.ARTILLERY and unitCats.MOBILE and not unitCats.EXPERIMENTAL then
                    unit['rngdata'].Role='Artillery'
                elseif unitCats.EXPERIMENTAL then
                    unit['rngdata'].Role='Experimental'
                elseif unitCats.NAVAL then
                    if unitCats.TECH2 and unitCats.INDIRECTFIRE and unitCats.CRUISER or unitCats.INDIRECTFIRE and unitCats.NAVAL and unitCats.BATTLESHIP and not unitCats.SERAPHIM then
                        unit['rngdata'].Role='MissileShip'
                    end
                elseif unitCats.SILO then
                    unit['rngdata'].Role='Silo'
                elseif unitCats.xsl0202 or unitCats.xel0305 or unitCats.xrl0305 then
                    unit['rngdata'].Role='Heavy'
                elseif unitCats.STEALTHFIELD then
                    unit['rngdata'].Role='Stealth'
                elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,unit) then
                    unit['rngdata'].Role='Sniper'
                    if EntityCategoryContains(categories.ual0201,unit) then
                        unit['rngdata'].GlassCannon=true
                    end
                elseif unitCats.SCOUT then
                    unit['rngdata'].Role='Scout'
                    if not self.ScoutUnit or self.ScoutUnit.Dead then
                        self.ScoutUnit = unit
                    end
                    if not intelrange or unitBp.Intel.RadarRadius > intelrange then
                        intelrange = unitBp.Intel.RadarRadius
                    end
                elseif unitCats.ANTIAIR then
                    unit['rngdata'].Role='AA'
                elseif unitCats.DIRECTFIRE then
                    unit['rngdata'].Role='Bruiser'
                elseif unitCats.SHIELD then
                    unit['rngdata'].Role='Shield'
                end
                if not unit['rngdata'].smartPos then
                    unit['rngdata'].smartPos = {0,0,0}
                end
                if not unitCats.ENGINEER then
                    unit:RemoveCommandCap('RULEUCC_Reclaim')
                    unit:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        if maxPlatoonStrikeDamage > 0 then
            self.PlatoonStrikeDamage = maxPlatoonStrikeDamage
        end
        if maxPlatoonStrikeRadius > 0 then
            self.PlatoonStrikeRadius = maxPlatoonStrikeRadius
        end
        if maxPlatoonStrikeRadiusDistance > 0 then
            self.PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
        end
        if maxPlatoonDPS > 0 then
            self.MaxPlatoonDPS = maxPlatoonDPS
        end
        if intelrange > 0 then
            self.IntelRange = intelrange
        end
        if not self.MaxPlatoonWeaponRange then
            self.MaxPlatoonWeaponRange=20
        end
    end,

    ChangeStateExt = function(self, name, state)
        --self:LogDebug(string.format('Changing state to: %s', tostring(name.StateName)))

        if not IsDestroyed(self) then
            self.State = state
            ChangeState(self, name)
        end
    end,

    PlatoonDisbandNoAssign = function(self)
        if self.BuilderHandle then
            self.BuilderHandle:RemoveHandle(self)
        end
        for k,v in self:GetPlatoonUnits() do
            v.PlatoonHandle = nil
        end
        self:GetBrain():DisbandPlatoon(self)
    end,

        --- This disbands the state machine platoon and sets engineers back to a manager.
    ---@param self AIPlatoon
    ExitStateMachine = function(self)
        if IsDestroyed(self) then
            return
        end
        local brain = self:GetBrain()
        local platUnits = self:GetPlatoonUnits()
        if platUnits then
            for _, unit in platUnits do
                if unit.Blueprint.CategoriesHash.ENGINEER then
                    unit.EngineerBuildQueue = {}
                    unit.PlatoonHandle = nil
                    unit.AssistSet = nil
                    unit.AssistPlatoon = nil
                    unit.UnitBeingAssist = nil
                    unit.ReclaimInProgress = nil
                    unit.CaptureInProgress = nil
                    unit.BuildFailedCount = nil
                    unit.AIPlatoonReference = nil
                    unit.Active = nil
                    if unit:IsPaused() then
                        unit:SetPaused(false)
                    end
                    if not unit.Dead and unit.BuilderManagerData then
                        if unit.BuilderManagerData.EngineerManager then
                            unit.BuilderManagerData.EngineerManager:TaskFinished(unit)
                            if unit.PlatoonHandle.Home and unit.PlatoonHandle.LocationType and unit.PlatoonHandle.LocationType ~= 'FLOATING' then
                                local hx = unit.PlatoonHandle.Pos[1] - unit.PlatoonHandle.Home[1]
                                local hz = unit.PlatoonHandle.Pos[3] - unit.PlatoonHandle.Home[3]
                                local homeDistance = hx * hx + hz * hz
                                if homeDistance < 6400 and brain.BuilderManagers[unit.PlatoonHandle.LocationType].FactoryManager.RallyPoint then
                                    --self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                                    local rallyPoint = aiBrain.BuilderManagers[unit.PlatoonHandle.LocationType].FactoryManager.RallyPoint
                                    local rx = unit.PlatoonHandle.Pos[1] - unit.PlatoonHandle.Home[1]
                                    local rz = unit.PlatoonHandle.Pos[3] - unit.PlatoonHandle.Home[3]
                                    local rallyPointDist = rx * rx + rz * rz
                                    if rallyPointDist > 100 then
                                        IssueMove({unit}, rallyPoint )
                                    end
                                    coroutine.yield(20)
                                end
                            end
                        end
                    end
                    --unit:SetCustomName('EngineerDisbanded')
                end
                if not unit.Dead then
                    IssueClearCommands({ unit })
                end
            end
        end
        brain:DisbandPlatoon(self)
    end,

}