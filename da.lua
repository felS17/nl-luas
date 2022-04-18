-- Dormant Aimbot with debug logs
local ui_main_enable = Menu.Switch("Main", "Dormant Aimbot", false, "Bind this to a key")
local ui_main_debug = Menu.Switch("Main", "Debug", false, "Debug logs")


local ui_settings_mindmg = Menu.SliderInt("Accuracy", "Minimum Damage", 1, 1, 50, "just leave it on 1 :)")
local ui_settings_hitchance = Menu.SliderInt("Accuracy", "Max Misses", 1, 1, 10, "Aimbot stops shooting after N-Amount of missed shots and dormant didn't update.")
local ui_combo_options = Menu.Combo("Accuracy", "Safety", {"Disabled", "After Miss", "Force"}, 0, "")

local ui_main_visualize = Menu.SwitchColor("Visuals", "Visualize Hitbox", false, Color.new(1.0, 1.0, 1.0, 1.0), "Draws a circle at target hitbox")

local IN_ATTACK = 1
local IN_ATTACK2 = 2048

local math_helper = {
    FixAngles = function(self, angles)
        while angles.pitch < -180.0 do
            angles.pitch = angles.pitch + 360.0
        end
        while angles.pitch > 180.0 do
            angles.pitch = angles.pitch - 360.0
        end

        while angles.yaw < -180.0 do
            angles.yaw = angles.yaw + 360.0
        end
        while angles.yaw > 180.0 do
            angles.yaw = angles.yaw - 360.0
        end

        if angles.pitch > 89.0 then
            angles.pitch = 89.0
        elseif angles.pitch < -89.0 then
            angles.pitch = -89.0
        end
        if angles.yaw > 180.0 then
            angles.yaw = 180.0
        elseif angles.pitch < -180.0 then
            angles.pitch = -180.0
        end

        return angles
    end,

    VectorAngles = function(self, src, dist)
        local forward = dist - src

        local tmp, yaw, pitch

        if forward.x == 0 and forward.y == 0 then
            yaw = 0

            if forward.z > 0 then
                pitch = 270
            else
                pitch = 90
            end

        else
            yaw = (math.atan2(forward.y, forward.x) * 180 / math.pi)
            if yaw < 0 then
                yaw = yaw + 360
            end

            tmp = math.sqrt(forward.x * forward.x + forward.y * forward.y)
            pitch = (math.atan2(-forward.z, tmp) * 180 / math.pi)

            if pitch < 0 then
                pitch = pitch + 360
            end

        end

        return self:FixAngles(QAngle.new(pitch, yaw, 0))
    end
}

local DormantAimbot = {
    aim_angles = nil,
    aim_point = nil,
    cmd = nil,

    target = nil,

    weapon = nil,
    lp = nil,

    debug = false,

    SanityCheck = function(self, ent)
        if ent == nil then
            if self.debug then
                print("[Dormant Aimbot] Target invalid: null pointer")
            end
            return false
        end

        if not ent:IsPlayer() then
            if self.debug then
                print("[Dormant Aimbot] Target invalid: entity is not player")
            end
            return false
        end

        local enemy = ent:GetPlayer()

        if not enemy:IsDormant() then
            if self.debug then
                print("[Dormant Aimbot] Target invalid: target is not dormant ")
            end
            return false
        end

        if enemy:IsTeamMate() then
            if self.debug then
                print("[Dormant Aimbot] Target invalid: target is a teammate ")
            end
            return false
        end

        if enemy:GetProp("DT_BasePlayer", "m_lifeState") ~= 0 then
            if self.debug then
                print("[Dormant Aimbot] Target invalid: target is dead")
            end
            return false
        end

        return true
    end,

    TargetSelection = function(self)

        local ents = EntityList.GetEntitiesByName("CCSPlayer")

        for ent_index = 1, #ents do

            local entity = ents[ent_index]

            if self:SanityCheck(entity) then
                self.target = entity:GetPlayer()
                return
            end

        end

    end,

    BestHitbox = function(self, ent)
        local best_hitgroup_id = nil
        local best_dmg = 0

        for group_id = 1, 7 do

            local enemy_aim_point = ent:GetHitboxCenter(group_id)

            local current_dmg = Cheat.FireBullet(self.lp, self.lp:GetEyePosition(), enemy_aim_point)

            if current_dmg > best_dmg then
                best_hitgroup_id = group_id
                best_dmg = current_dmg
            end

        end

        return best_hitgroup_id
    end,

    FireCheck = function(self)
        if not self:SanityCheck(self.target) then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: target is invalid")
            end
            return false
        end

        if self.weapon == nil then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: weapon null pointer")
            end
            return false
        end

        if self.weapon:IsKnife() or self.weapon:IsReloading() or self.weapon:IsGrenade() then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: weapon is reloading or invalid")
            end
            return false
        end

        if self.target:GetRenderOrigin():Length2D() > self.weapon:GetWeaponRange() then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: weapon out of range")
            end
            return false
        end

        if self.weapon:GetProp("DT_BaseCombatWeapon", "m_flNextPrimaryAttack") > g_GlobalVars.curtime then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: weapon is not ready")
            end
            return false
        end

        if not (bit.band(self.lp:GetProp("DT_BasePlayer", "m_fFlags"), 1) == 1) then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: localplayer is not on the ground")
            end
            return false
        end

        if self.weapon:GetProp("DT_WeaponCSBaseGun", "m_zoomLevel") ~= nil and
            self.weapon:GetProp("DT_WeaponCSBaseGun", "m_zoomLevel") == 0 then

            if self.debug then
                print("[Dormant Aimbot] Fire check failed: not scoped")
            end

            return false
        end

        return true
    end,

    HitChance = function(self) 
        local distance = self.lp:GetRenderOrigin():DistTo(self.aim_point)
        local weapon_inaccuarcy = math.max(self.weapon:GetInaccuracy(self.weapon), 0.00000001)

        local b = math.sqrt(math.tan(weapon_inaccuarcy) * 3.932) * distance

        return math.min((5.1432 / b) * 200, 100)
    end,

    Run = function(self, cmd)
        if not ui_main_enable:GetBool() then
            return
        end

        self.cmd = cmd
        self.lp = EntityList.GetClientEntity(EngineClient.GetLocalPlayer()):GetPlayer()
        self.weapon = self.lp:GetActiveWeapon()
        self.debug = ui_main_debug:GetBool()

        self:TargetSelection()

        if not self:FireCheck() then
            return
        end

        if self:BestHitbox(self.target) == nil then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: target unreachable")
            end
            return
        end

        self.aim_point = self.target:GetHitboxCenter(self:BestHitbox(self.target))
        self.aim_angles = math_helper:VectorAngles(self.lp:GetEyePosition(), self.aim_point)

        if Cheat.FireBullet(self.lp, self.lp:GetEyePosition(), self.aim_point) < ui_settings_mindmg:GetInt() then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: min dmg is not satisfies settings")
            end
            return
        end

        if self:HitChance() <= ui_settings_hitchance:GetInt() then
            if self.debug then
                print("[Dormant Aimbot] Fire check failed: hitchance is not satisfies settings")
            end
            return
        end

        if self.weapon:GetProp("DT_WeaponCSBaseGun", "m_zoomLevel") ~= nil and
            self.weapon:GetProp("DT_WeaponCSBaseGun", "m_zoomLevel") == 0 then

            cmd.buttons = bit.bor(cmd.buttons, IN_ATTACK2)

            return
        end

        cmd.viewangles = self.aim_angles

        cmd.buttons = bit.bor(cmd.buttons, IN_ATTACK)

        if self.debug then
            print("[Dormant Aimbot] Fired at " .. self.target:GetName())
        end
    end

}

local function run_cb(cmd)
    DormantAimbot:Run(cmd)
end

Cheat.RegisterCallback("createmove", run_cb)