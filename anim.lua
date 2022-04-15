-- Perfect anim breaker for nvl

local fakelag_limit = Menu.FindVar("Aimbot", "Anti Aim", "Fake Lag", "Limit")
local Menu_MultiCum = Menu.MultiCombo
local i_like_cocks = Menu_MultiCum("Main","Custom animations", {"Static legs in air", "Pitch 0 on land", "Backwards legs" },0,"")
local animation_breaker,ffi_handler = {}, {}
local m_iGroundTicks, m_flEndTime = 1, 0
local m_bOnLand = false

ffi.cdef[[
    typedef struct {
        uint8_t r;
        uint8_t g;
        uint8_t b;
        uint8_t a;
    } color_struct_t;
    typedef void (__cdecl* console_color_print)(void*,const color_struct_t&, const char*, ...);
    typedef float*(__thiscall* bound)(void*);
    typedef void*(__thiscall* c_entity_list_get_client_entity_t)(void*, int);
    typedef void*(__thiscall* c_entity_list_get_client_entity_from_handle_t)(void*, uintptr_t);
    struct pose_params_t {
        char pad[8];
        float     m_flStart;
        float     m_flEnd;
        float     m_flState;
    };
    bool PlaySound(const char *pszSound, void *hmod, uint32_t fdwSound);
]]
ffi_handler.bind_argument = function(fn, arg)
    return function(...)
        return fn(arg, ...)
    end
end
ffi_handler.animstate_offset = 0x9960
ffi_handler.interface_type = ffi.typeof("uintptr_t**")
local pose_parameter_pattern = "55 8B EC 8B 45 08 57 8B F9 8B 4F 04 85 C9 75 15"
ffi_handler.get_pose_parameters = ffi.cast( "struct pose_params_t*(__thiscall* )( void*, int )", Utils.PatternScan( "client.dll", pose_parameter_pattern))
ffi_handler.i_client_entity_list = ffi.cast(ffi_handler.interface_type, Utils.CreateInterface("client.dll", "VClientEntityList003"))
ffi_handler.get_client_entity = ffi_handler.bind_argument(ffi.cast("c_entity_list_get_client_entity_t", ffi_handler.i_client_entity_list[0][3]), ffi_handler.i_client_entity_list)
animation_breaker.cache = {}
animation_breaker.set_params = function(player_ptr, layer, start_val, end_val)
    player_ptr = ffi.cast("unsigned int", player_ptr)
    if player_ptr == 0x0 then
        return false
    end
    local studio_hdr = ffi.cast("void**", player_ptr + 0x2950)[0]
    if studio_hdr == nil then
        return false
    end
    local pose_params = ffi_handler.get_pose_parameters(studio_hdr, layer)
    if pose_params == nil or pose_params == 0x0 then
        return
    end
    if animation_breaker.cache[layer] == nil then
        animation_breaker.cache[layer] = {}
        animation_breaker.cache[layer].m_flStart = pose_params.m_flStart
        animation_breaker.cache[layer].m_flEnd = pose_params.m_flEnd
        animation_breaker.cache[layer].m_flState = pose_params.m_flState
        animation_breaker.cache[layer].installed = false
        return true
    end
    if start_val ~= nil and not animation_breaker.cache[layer].installed then
        pose_params.m_flStart   = start_val
        pose_params.m_flEnd     = end_val
        pose_params.m_flState   = (pose_params.m_flStart + pose_params.m_flEnd) / 2
        animation_breaker.cache[layer].installed = true
        return true
    end
    if animation_breaker.cache[layer].installed then
        pose_params.m_flStart   = animation_breaker.cache[layer].m_flStart
        pose_params.m_flEnd     = animation_breaker.cache[layer].m_flEnd
        pose_params.m_flState   = animation_breaker.cache[layer].m_flState
        animation_breaker.cache[layer].installed = false
        return true
    end
    return false
end
EngineClient.ExecuteClientCmd("clear")

animation_breaker.handle_prediction = function(cmd)
    local local_player = ffi_handler.get_client_entity(EngineClient.GetLocalPlayer())
    if local_player == nil then
        return
    end
    local local_player_addr = ffi.cast("unsigned int", local_player)
    if local_player_addr == 0x0 then
        return
    end
    local animstate = ffi.cast( "void**", local_player_addr + ffi_handler.animstate_offset)[0]
    if animstate == nil then
        return
    end
    animstate = ffi.cast("unsigned int", animstate)
    if animstate == 0x0 then
        return
    end
    local landing_anim = ffi.cast("bool*", animstate + 0x109)[0]
    if landing_anim == nil then
        return
    end

    if i_like_cocks:Get(1) then 
        animation_breaker.set_params(local_player, 6, 1, 1 -0.1)
    else 
        animation_breaker.set_params(local_player, 6, 0, 0 -0.1)
    end
    if i_like_cocks:Get(2) then 
        if m_bOnLand then
            animation_breaker.set_params(local_player, 12, -12, -12 -0.1)
        end
    end

    if i_like_cocks:Get(3) then 
        animation_breaker.set_params(local_player, 0, 1, 1 -0.1)
    end


end
animation_breaker.handle_cmove = function()
    local local_player = ffi_handler.get_client_entity(EngineClient.GetLocalPlayer())
    if local_player == nil then
        return
    end
    for k, v in pairs(animation_breaker.cache) do
        animation_breaker.set_params(local_player, k)
    end
end
animation_breaker.on_destroy = function()
    local local_player = ffi_handler.get_client_entity(EngineClient.GetLocalPlayer())
    if local_player == nil then
        return
    end
   
    animation_breaker.set_params(local_player, 6, 0, 0 -0.1)
   
end
local e = EntityList.GetLocalPlayer()
local landing_stuff = function()
    e = EntityList.GetLocalPlayer()
    if e == nil then
        return
    end
    if e:GetProp("m_iHealth") <= 0 then
        return
    end
    local m_bOnGround = bit.band(e:GetProp("m_fFlags"), bit.lshift(1,0)) ~= 0
    if m_bOnGround then
        m_iGroundTicks = m_iGroundTicks + 1
    else
        m_iGroundTicks = 0
        m_flEndTime = GlobalVars.curtime + 1
    end 
    m_bOnLand = false
    if m_iGroundTicks > fakelag_limit:GetInt()+1 and m_flEndTime > GlobalVars.curtime then
        m_bOnLand = true
    end
end


Cheat.RegisterCallback("draw", landing_stuff)
Cheat.RegisterCallback("createmove", animation_breaker.handle_cmove)
Cheat.RegisterCallback("prediction", animation_breaker.handle_prediction)
Cheat.RegisterCallback("destroy", animation_breaker.on_destroy)

