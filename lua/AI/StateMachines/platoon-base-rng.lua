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
        for k, unit in units do
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
                if unitCats.GUNSHIP and not unit.ApproxDPS then
                    for _, weapon in unitBp.Weapon or {} do
                        if not weapon.CannotAttackGround and weapon.RangeCategory == 'UWRC_DirectFire' then
                            unit.ApproxDPS = RUtils.CalculatedDPSRNG(weapon) --weaponBlueprint.RateOfFire * (weaponBlueprint.MuzzleSalvoSize or 1) *  weaponBlueprint.Damage
                        end
                    end
                end
                if not unit.MaxWeaponRange and unitBp.Weapon[1].MaxRadius and not unitBp.Weapon[1].ManualFire then
                    unit.MaxWeaponRange = unitBp.Weapon[1].MaxRadius
                end
                if not unit.MaxWeaponRange then
                    for _, weapon in unitBp.Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if weapon.WeaponCategory == 'Anti Air' then
                            continue
                        end
                        if not unit.MaxWeaponRange or weapon.MaxRadius > unit.MaxWeaponRange then
                            -- save the weaponrange 
                            unit.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                unit.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                unit.WeaponArc = 'high'
                            else
                                unit.WeaponArc = 'none'
                            end
                        end
                    end
                end
                if unit.MaxWeaponRange and (unitBp.Weapon and unitBp.Weapon[1].RangeCategory == 'UWRC_DirectFire' and not self.MaxDirectFireRange or self.MaxDirectFireRange < unit.MaxWeaponRange) then
                    self.MaxDirectFireRange = unit.MaxWeaponRange
                end
                if unit.MaxWeaponRange and (not self.MaxPlatoonWeaponRange or self.MaxPlatoonWeaponRange < unit.MaxWeaponRange) then
                    self.MaxPlatoonWeaponRange = unit.MaxWeaponRange
                end
            end
            if not unit.MaxWeaponRange then
                unit.MaxWeaponRange = 0
            end
            if (unit.Sync.Regen>0) or not unit.initialized then
                unit.initialized=true
                if unitCats.ARTILLERY and unitCats.MOBILE and not unitCats.EXPERIMENTAL then
                    self:LogDebug(string.format('Assign Artillery role'))
                    unit.Role='Artillery'
                elseif unitCats.EXPERIMENTAL then
                    unit.Role='Experimental'
                elseif unitCats.SILO then
                    unit.Role='Silo'
                elseif unitCats.xsl0202 or unitCats.xel0305 or unitCats.xrl0305 then
                    unit.Role='Heavy'
                elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,unit) then
                    self:LogDebug(string.format('Assign Sniper role to '..unit.UnitId))
                    unit.Role='Sniper'
                    if EntityCategoryContains(categories.ual0201,unit) then
                        unit.GlassCannon=true
                    end
                elseif unitCats.SCOUT then
                    unit.Role='Scout'
                    if not self.ScoutUnit or self.ScoutUnit.Dead then
                        self.ScoutUnit = unit
                    end
                elseif unitCats.ANTIAIR then
                    unit.Role='AA'
                elseif unitCats.DIRECTFIRE then
                    unit.Role='Bruiser'
                elseif unitCats.SHIELD then
                    unit.Role='Shield'
                end
                unit:RemoveCommandCap('RULEUCC_Reclaim')
                unit:RemoveCommandCap('RULEUCC_Repair')
            end
        end
        if not self.MaxPlatoonWeaponRange then
            self.MaxPlatoonWeaponRange=20
        end
    end,

    ChangeStateExt = function(self, name, state)
        self:LogDebug(string.format('Changing state to: %s', tostring(name.StateName)))

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

}