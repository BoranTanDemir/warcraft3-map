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
