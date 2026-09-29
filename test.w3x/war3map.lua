function InitGlobals()
end

 -- ============================================================================
-- LUA SPELL FRAMEWORK (WITH DEBUGGING)
-- ============================================================================
Spell = {
    handlers = {},
    Debug = true -- Set to false to disable in-game debug chat messages
}

-- Debug print helper using WC3 colored text
function Spell.Log(msg)
    if Spell.Debug then
        print("|cffffcc00[SpellEngine]|r " .. tostring(msg))
    end
end

-- Convert string rawcodes ('A000') or integers to FourCC
function Spell.ToId(raw)
    return type(raw) == "string" and FourCC(raw) or raw
end

--- Register a spell handler table to an ability rawcode
-- @param rawcode string|integer (e.g., 'A000' or FourCC('A000'))
-- @param config table containing callback functions (onEffect, onChannel, etc.)
function Spell.Register(rawcode, config)
    local id = Spell.ToId(rawcode)
    Spell.handlers[id] = config
    Spell.Log("Registered handler for ability rawcode: " .. tostring(rawcode) .. " (ID: " .. tostring(id) .. ")")
end

-- Universal Event Payload Generator
local function CreateEventContext()
    local caster = GetTriggerUnit()
    local spellId = GetSpellAbilityId()
    return {
        caster  = caster,
        ability = spellId,
        level   = GetUnitAbilityLevel(caster, spellId),
        target  = GetSpellTargetUnit(),
        targetX = GetSpellTargetX(),
        targetY = GetSpellTargetY(),
        x       = GetUnitX(caster),
        y       = GetUnitY(caster),
        facing  = GetUnitFacing(caster)
    }
end

-- Central Event Dispatcher
local function OnGlobalSpellEvent(eventId)
    local context = CreateEventContext()
    local handler = Spell.handlers[context.ability]

    if not handler then
        return
    end

    local unitName = GetUnitName(context.caster)

    if eventId == EVENT_PLAYER_UNIT_SPELL_EFFECT and handler.onEffect then
        Spell.Log("EVENT_EFFECT -> " .. unitName .. " cast ID: " .. tostring(context.ability))
        handler.onEffect(context)
    elseif eventId == EVENT_PLAYER_UNIT_SPELL_CHANNEL and handler.onChannel then
        Spell.Log("EVENT_CHANNEL -> " .. unitName .. " channeling ID: " .. tostring(context.ability))
        handler.onChannel(context)
    elseif eventId == EVENT_PLAYER_UNIT_SPELL_ENDCAST and handler.onEnd then
        Spell.Log("EVENT_ENDCAST -> " .. unitName .. " finished ID: " .. tostring(context.ability))
        handler.onEnd(context)
    end
end

-- Framework Initialization Hook
local function InitSpellFramework()
    local trg = CreateTrigger()
    for i = 0, GetBJMaxPlayerSlots() - 1 do
        local p = Player(i)
        TriggerRegisterPlayerUnitEvent(trg, p, EVENT_PLAYER_UNIT_SPELL_CHANNEL, nil)
        TriggerRegisterPlayerUnitEvent(trg, p, EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(trg, p, EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
    end

    TriggerAddAction(trg, function()
        OnGlobalSpellEvent(GetTriggerEventId())
    end)

    Spell.Log("Framework triggers successfully attached to all player slots.")
end

-- Run initialization on map startup
local oldInit = InitGlobals
function InitGlobals()
    if oldInit then oldInit() end
    InitSpellFramework()
end

-- ============================================================================
-- OMEGA ZERO: TRIPLE SLASH (MUI COMBO)
-- ============================================================================
local ABIL_TRIPLE_SLASH = 'A001' -- Rawcode of your custom spell button
local COMBO_WINDOW      = 1.25   -- Seconds player has to press key again for next hit
local DASH_DISTANCE     = 75.0   -- Forward nudge per slash to give it punchy feel

Spell.Register(ABIL_TRIPLE_SLASH, {
    onEffect = function(e)
        local c = e.caster

        -- Initialize persistent state table on the unit handle if missing
        c.tripleSlash = c.tripleSlash or {
            step = 0,
            timer = CreateTimer()
        }

        local state = c.tripleSlash

        -- Reset Timer callback helper
        local function StartComboWindow()
            PauseTimer(state.timer)
            TimerStart(state.timer, COMBO_WINDOW, false, function()
                state.step = 0 -- Window expired, reset combo to Strike 1
            end)
        end

        -- Calculate forward direction vector
        local facingRad = math.rad(e.facing)
        local cosF = math.cos(facingRad)
        local sinF = math.sin(facingRad)

        -- Helper to nudge Zero forward during slashes
        local function PerformNudge(dist)
            local nx = GetUnitX(c) + (dist * cosF)
            local ny = GetUnitY(c) + (dist * sinF)
            SetUnitPosition(c, nx, ny)
        end

        -- Helper for slash damage
        local function DealSlashDamage(radius, damage, sfxPath)
            local x, y = GetUnitX(c), GetUnitY(c)
            DestroyEffect(AddSpecialEffect(sfxPath, x, y))

            local g = CreateGroup()
            GroupEnumUnitsInRange(g, x, y, radius, nil)

            ForGroup(g, function()
                local target = GetEnumUnit()
                if IsUnitEnemy(target, GetOwningPlayer(c)) and not IsUnitDead(target) then
                    UnitDamageTarget(c, target, damage, true, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL,
                        WEAPON_TYPE_WHOKNOWS)
                end
            end)
            DestroyGroup(g)
        end

        -- ====================================================================
        -- COMBO STATE MACHINE
        -- ====================================================================
        if state.step == 0 then
            -- ----------------------------------------------------------------
            -- STRIKE 1: Quick Slash
            -- ----------------------------------------------------------------
            state.step = 1
            SetUnitAnimationByIndex(c, 1) -- Set to your model's Slash 1 animation index
            SetUnitTimeScale(c, 1.5)      -- Fast snappy animation

            PerformNudge(DASH_DISTANCE)
            DealSlashDamage(150.0, 75.0, "Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl")

            StartComboWindow()
        elseif state.step == 1 then
            -- ----------------------------------------------------------------
            -- STRIKE 2: Follow-up Cross Slash
            -- ----------------------------------------------------------------
            state.step = 2
            SetUnitAnimationByIndex(c, 2) -- Slash 2 animation
            SetUnitTimeScale(c, 1.5)

            PerformNudge(DASH_DISTANCE)
            DealSlashDamage(150.0, 100.0, "Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl")

            StartComboWindow()
        elseif state.step == 2 then
            -- ----------------------------------------------------------------
            -- STRIKE 3: Heavy Downward Finisher
            -- ----------------------------------------------------------------
            PauseTimer(state.timer)
            state.step = 0                -- Reset combo back to start

            SetUnitAnimationByIndex(c, 3) -- Heavy slam/slash animation
            SetUnitTimeScale(c, 1.2)

            PerformNudge(DASH_DISTANCE * 1.5)

            -- Small delay hit for the heavy finisher weight
            Spell.Ticker(0.08, 0.08, function()
                DealSlashDamage(225.0, 180.0, "Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl")
                SetUnitTimeScale(c, 1.0) -- Reset animation speed
            end)
        end
    end
})

function CreateUnitsForPlayer0()
local p = Player(0)
local u
local unitID
local t
local life

u = BlzCreateUnitWithSkin(p, FourCC("O000"), -626.3, 266.8, 234.543, FourCC("O000"))
end

function CreateNeutralHostile()
local p = Player(PLAYER_NEUTRAL_AGGRESSIVE)
local u
local unitID
local t
local life

u = BlzCreateUnitWithSkin(p, FourCC("nfsp"), -173.2, -432.2, 242.618, FourCC("nfsp"))
u = BlzCreateUnitWithSkin(p, FourCC("nfsp"), -51.9, -432.2, 190.717, FourCC("nfsp"))
u = BlzCreateUnitWithSkin(p, FourCC("nfsp"), -752.0, -277.5, 79.148, FourCC("nfsp"))
end

function CreatePlayerBuildings()
end

function CreatePlayerUnits()
CreateUnitsForPlayer0()
end

function CreateAllUnits()
CreatePlayerBuildings()
CreateNeutralHostile()
CreatePlayerUnits()
end

function InitCustomPlayerSlots()
SetPlayerStartLocation(Player(0), 0)
SetPlayerColor(Player(0), ConvertPlayerColor(0))
SetPlayerRacePreference(Player(0), RACE_PREF_HUMAN)
SetPlayerRaceSkin(Player(0), RACE_PREF_RANDOM)
SetPlayerRaceSelectable(Player(0), true)
SetPlayerController(Player(0), MAP_CONTROL_USER)
end

function InitCustomTeams()
SetPlayerTeam(Player(0), 0)
end

function main()
SetCameraBounds(-15616.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), -15872.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM), 15616.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), 15360.0 - GetCameraMargin(CAMERA_MARGIN_TOP), -15616.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), 15360.0 - GetCameraMargin(CAMERA_MARGIN_TOP), 15616.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), -15872.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM))
SetDayNightModels("Environment\\DNC\\DNCLordaeron\\DNCLordaeronTerrain\\DNCLordaeronTerrain.mdl", "Environment\\DNC\\DNCLordaeron\\DNCLordaeronUnit\\DNCLordaeronUnit.mdl")
SetHDWaterParamsEx(0, 0, 0, false, 20, 0, 100, 10, 0, 50, 100, 100)
NewSoundEnvironment("Default")
SetAmbientDaySound("LordaeronSummerDay")
SetAmbientNightSound("LordaeronSummerNight")
SetMapMusic("Music", true, 0)
CreateAllUnits()
InitBlizzard()
InitGlobals()
end

function config()
SetMapName("TRIGSTR_004")
SetMapDescription("TRIGSTR_006")
SetPlayers(1)
SetTeams(1)
SetGamePlacement(MAP_PLACEMENT_USE_MAP_SETTINGS)
DefineStartLocation(0, -192.0, 0.0)
InitCustomPlayerSlots()
SetPlayerSlotAvailable(Player(0), MAP_CONTROL_USER)
InitGenericPlayerSlots()
end

