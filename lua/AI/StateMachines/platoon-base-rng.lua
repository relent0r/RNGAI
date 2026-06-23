local AIBasePlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local NavUtils = import('/lua/sim/navutils.lua')
local ALLBPS = __blueprints

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
        if not self['rngdata'] then
            self['rngdata'] = {}
        end
        if not self['rngdata'].UIDSet then
            local uid = string.format("%d_%d", GetGameTick(), Random(1000, 9999))
            self.rngdata.UID = uid
        end
        self.Units = units
        local bombCoolDown
        local maxPlatoonStrikeDamage = 0
        local maxPlatoonDPS = 0
        local maxPlatoonStrikeRadius = 20
        local maxPlatoonStrikeRadiusDistance = 0
        local intelrange = 0
        local minPlatoonSpeed = 999
        if not self['rngdata'] then
            self['rngdata'] = {}
        end
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
            StateUtils.SetUnitCategoryRanges(unit)
            if unitCats.BOMBER or unitCats.GUNSHIP then
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
                                bombCoolDown = math.max(weapon.RackReloadTimeout or 0, 1 / weapon.RateOfFire)
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
                        if unitCats.STRATEGICBOMBER then
                            self.StratBomberPresent = true
                        end
                        unit['rngdata'].BombCoolDown = bombCoolDown
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
                end
            end
            if (unit['rngdata'].CategoryDirectFireRange and not self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxDirectFireRange and self['rngdata'].MaxDirectFireRange < unit['rngdata'].CategoryDirectFireRange) and not unitCats.SCOUT then
                self['rngdata'].MaxDirectFireRange = unit['rngdata'].MaxWeaponRange
            end
            if unit['rngdata'].MaxWeaponRange and (not self['rngdata'].MaxPlatoonWeaponRange or self['rngdata'].MaxPlatoonWeaponRange < unit['rngdata'].MaxWeaponRange) then
                 self['rngdata'].MaxPlatoonWeaponRange = unit['rngdata'].MaxWeaponRange
            end
            if not unit['rngdata'].MaxWeaponRange then
                unit['rngdata'].MaxWeaponRange = 0
            end
            local maxSpeed = unit.Blueprint.Physics.MaxSpeed or 0
            if maxSpeed > 0 and maxSpeed < minPlatoonSpeed then
                minPlatoonSpeed = maxSpeed
            end
            if unitCats.SATELLITE then
                if not self.NovaxUnits then
                    self.NovaxUnits = {}
                end
                if not self.NovaxUnits[unit.EntityId] then
                    local unitDPS = RUtils.CalculatedDPSRNG(ALLBPS['xea0002'].Weapon[1])
                    self.NovaxUnits[unit.EntityId] = {Unit = unit, CurrentTarget = nil, CurrentTargetHealth = nil, UnitDPS = unitDPS }
                    maxPlatoonDPS = maxPlatoonDPS + unitDPS
                end
            end
            if unitCats.ARTILLERY and ( unitCats.STRUCTURE and unitCats.TECH3 or unitCats.EXPERIMENTAL ) then
                if unit.Blueprint.Weapon[1].MaxRadius > self['rngdata'].MaxPlatoonWeaponRange then
                    self['rngdata'].MaxPlatoonWeaponRange = unit.Blueprint.Weapon[1].MaxRadius
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
                    elseif unitCats.TECH2 and unitCats.CRUISER then
                        unit['rngdata'].Role='Cruiser'
                    elseif unitCats.TECH2 and unitCats.SHIELD then
                        unit['rngdata'].Role='Shield'
                    elseif unitCats.TECH2 and unitCats.STEALTHFIELD then
                        unit['rngdata'].Role='Stealth'
                    elseif unitCats.TECH1 and unitCats.FRIGATE then
                        unit['rngdata'].Role='Frigate'
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
                local callBacks = StateUtils.GetCallBackCheck(unit)
            end
        end
        if maxPlatoonStrikeDamage > 0 then
            self['rngdata'].PlatoonStrikeDamage = maxPlatoonStrikeDamage
        end
        if maxPlatoonStrikeRadius > 0 then
            self['rngdata'].PlatoonStrikeRadius = maxPlatoonStrikeRadius
        end
        if maxPlatoonStrikeRadiusDistance > 0 then
            self['rngdata'].PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
        end
        if maxPlatoonDPS > 0 then
            self['rngdata'].MaxPlatoonDPS = maxPlatoonDPS
        end
        if intelrange > 0 then
            self['rngdata'].IntelRange = intelrange
        end
        if not self['rngdata'].MaxPlatoonWeaponRange then
            self['rngdata'].MaxPlatoonWeaponRange = 20
        end
        if minPlatoonSpeed == 999 then minPlatoonSpeed = 0 end
        if not self['rngdata'].MinPlatoonSpeed then
            self['rngdata'].MinPlatoonSpeed = minPlatoonSpeed
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
                    StateUtils.UpdateEngineerBuildQueueRNG(unit)
                    unit.PlatoonHandle = nil
                    unit.AssistSet = nil
                    unit.AssistPlatoon = nil
                    unit.UnitBeingAssist = nil
                    unit.ReclaimInProgress = nil
                    unit.CaptureInProgress = nil
                    unit.BuildFailedCount = nil
                    unit.AIPlatoonReference = nil
                    unit.Active = nil
                    if not unit.Dead and unit:IsPaused() then
                        unit:SetPaused(false)
                    end
                    if not unit.Dead and unit.BuilderManagerData then
                        if unit.BuilderManagerData.EngineerManager then
                            unit.BuilderManagerData.EngineerManager:TaskFinished(unit)
                    if self.Home and self.LocationType and self.LocationType ~= 'FLOATING' then
                        local hx = platUnits[1]:GetPosition()[1] - self.Home[1]
                        local hz = platUnits[1]:GetPosition()[3] - self.Home[3]
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
                    if unit.rngdata and unit.rngdata.ReservedMarker then
                        StateUtils.ReleaseMassMarker(unit, unit['rngdata'].ReservedMarker)
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

    FindAlternateLandingPosition = State {
        StateName = "FindAlternateLandingPosition",
        Main = function(self)
            local aiBrain = self:GetBrain()
            local avoidPos = self.BuilderData.AvoidPos
            if not avoidPos then
                self.AlternativeLandingFailed = true
                return
            end

            local layer = self.MovementLayer or 'Land'
            local searchRadius = 120 -- Search area for a safe LZ
            local threatMax = 5 -- Maximum acceptable surface threat for landing
            local preferredLabel = NavUtils.GetLabel('Land', avoidPos)

            -- Search for safe ground markers within the search radius
            local markerlist = NavUtils.DirectionsFromWithThreatThreshold(layer, avoidPos, searchRadius, aiBrain, NavUtils.ThreatFunctions.AntiSurface, threatMax, aiBrain.BrainIntel.IMAPConfig.Rings)

            if not table.empty(markerlist) then
                -- 1. Label Filtering: Prioritize landing on the same landmass/label
                local sameLabelMarkers = {}
                if preferredLabel and preferredLabel ~= 0 then
                    for _, m in markerlist do
                        if NavUtils.GetLabel('Land', m) == preferredLabel then
                            table.insert(sameLabelMarkers, m)
                        end
                    end
                end

                local candidates = not table.empty(sameLabelMarkers) and sameLabelMarkers or markerlist

                -- Sort candidates by proximity to original objective
                table.sort(candidates, function(a, b)
                    local distASq = VDist2Sq(a[1], a[3], avoidPos[1], avoidPos[3])
                    local distBSq = VDist2Sq(b[1], b[3], avoidPos[1], avoidPos[3])
                    return distASq < distBSq
                end)
                
                -- 2. Tactical Validation: Verify the closest "safe" spot isn't actually hot with units
                local bestPos = false
                local cargoThreat = self.CurrentPlatoonThreatAntiSurface or 0
                for _, pos in candidates do
                    local numEnemy = aiBrain:GetNumUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, pos, 25, 'Enemy')
                    if numEnemy == 0 then
                        bestPos = pos
                        break
                    else
                        local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, pos, 25, 'Enemy')
                        local spotAntiAirThreat = 0
                        local spotSurfaceThreat = 0
                        for _, u in enemyUnits do
                            if not u.Dead then
                                local bp = u.Blueprint.Defense
                                spotAntiAirThreat = spotAntiAirThreat + (bp.AirThreatLevel or 0)
                                spotSurfaceThreat = spotSurfaceThreat + (bp.SurfaceThreatLevel or 0)
                            end
                        end
                        if spotAntiAirThreat < 5 and spotSurfaceThreat <= cargoThreat * 0.5 then
                            bestPos = pos
                            break
                        end
                    end
                end

                -- Fallback to the closest marker if the tactical check is too strict for all candidates
                bestPos = bestPos or candidates[1]
                -- Provide the new position to the transport
                self.BuilderData.Position = bestPos
                self.AlternativeLandingSet = true
            else
                self.AlternativeLandingFailed = true
            end
            
            -- Loop until detached from transport, then return to standard decision logic
            while not IsDestroyed(self) do
                local attached = false
                local units = self:GetPlatoonUnits()
                for _, u in units do
                    if not u.Dead and u:IsUnitState('Attached') then
                        attached = true
                        break
                    end
                end
                
                if not attached then
                    --LOG(string.format('RNGAI: FindAlternateLandingPosition: Platoon %s detached. Returning to decision logic.', self.PlatoonName))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                coroutine.yield(20)
            end
        end,
    },
}