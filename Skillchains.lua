_addon.author  = 'Ivaar, Additional features by Nsane'
_addon.command = 'sc'
_addon.name    = 'Skillchains'
_addon.version = '2025.9.2'

-- Dependencies (Windower environment)
require('luau')
require('pack')
require('actions')
local texts  = require('texts')
local skills = require('skills')

-- Locals and utilities --------------------------------------------------------
local S, L = S, L
local res = res
local config = config
local windower = windower
local ActionPacket = ActionPacket

-- Constants ------------------------------------------------------------------
local STATIC_JOBS = S{'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH','GEO','RUN'}

local default = {}
default.Show = { burst=STATIC_JOBS, pet=S{'BST','SMN'}, props=STATIC_JOBS, spell=S{'SCH','BLU'}, step=STATIC_JOBS, timer=STATIC_JOBS, weapon=STATIC_JOBS }
default.UpdateFrequency = 0.1
default.aeonic = false
default.color = true
default.display = { text={ size=12, font='Consolas' }, pos={ x=0, y=0 }, bg={ visible=true } }

local settings = config.load(default)
local skill_props = texts.new('', settings.display, settings)

local MESSAGE_IDS     = S{110,185,187,317,802}
local SKILLCHAIN_IDS  = S{288,289,290,291,292,293,294,295,296,297,298,299,300,301,385,386,387,388,389,390,391,392,393,394,395,396,397,767,768,769,770}
local BUFF_DUR        = {[163]=40,[164]=30,[470]=60}

local info        = {}
local resonating  = {}
local buffs       = {}

-- Colors ---------------------------------------------------------------------
local colors = {
    Light=		'\\cs(255,255,255)',
    Dark=		'\\cs(135,135,135)',
    Ice=		'\\cs(0, 255, 255)',
    Water=		'\\cs(0, 150, 255)',
    Earth=		'\\cs(255, 255, 28)',
    Wind=		'\\cs(51, 255, 20)',
    Fire=		'\\cs(255, 22, 12)',
    Lightning=	'\\cs(233, 0, 255)',
}
colors.Darkness			= colors.Dark
colors.Umbra			= colors.Dark
colors.Compression		= colors.Dark
colors.Radiance			= colors.Light
colors.Transfixion		= colors.Light
colors.Induration		= colors.Ice
colors.Reverberation	= colors.Water
colors.Scission			= colors.Earth
colors.Detonation		= colors.Wind
colors.Liquefaction		= colors.Fire
colors.Impaction		= colors.Lightning

-- Color helpers ---------------------------------------------------------------
local function AEONIC_TIER_COLOR(lv)
    if lv >= 3 then return		'\\cs(255,51,51)'
    elseif lv == 2 then return	'\\cs(255,153,51)'
    else return					'\\cs(255,255,102)'
    end
end

local prop_grad_palette = {
    Gravitation   = {colors.Dark,      colors.Earth},
    Fragmentation = {colors.Lightning, colors.Wind},
    Fusion        = {colors.Light,     colors.Fire},
    Distortion    = {colors.Ice,       colors.Water},
}

local _rgb_cache = {}
local function _parse_cs_rgb(cs)
    local c = _rgb_cache[cs]
    if c then return c[1], c[2], c[3] end
    local r,g,b = cs:match("\\cs%((%d+),%s*(%d+),%s*(%d+)%)")
    r = tonumber(r) or 255
    g = tonumber(g) or 255
    b = tonumber(b) or 255
    _rgb_cache[cs] = {r,g,b}
    return r,g,b
end

local function _cs_from_rgb(r,g,b)
    local clamp = function(v) return math.max(0, math.min(255, v)) end
    return ('\\cs(%d,%d,%d)'):format(clamp(r), clamp(g), clamp(b))
end

local function grad_colorize_word(word, cs_a, cs_b)
    local ar,ag,ab = _parse_cs_rgb(cs_a)
    local br,bg,bb = _parse_cs_rgb(cs_b)
    local idxs = {}
    for i=1,#word do
        local ch = word:sub(i,i)
        if ch:match('[%w]') then idxs[#idxs+1] = i end
    end
    local n = #idxs
    if n == 0 then return word end
    local out = {}
    local function lerp(a,b,t) return a + (b-a)*t end
    for i=1,#word do out[i] = word:sub(i,i) end
    for k=1,n do
        local pos = (k-1)/(n-1)
        local t = pos <= 0.5 and (pos/0.5) or ((1-pos)/0.5)
        local r = math.floor(lerp(ar, br, t) + 0.5)
        local g = math.floor(lerp(ag, bg, t) + 0.5)
        local b = math.floor(lerp(ab, bb, t) + 0.5)
        local i = idxs[k]
        out[i] = ("%s%s\\cr"):format(_cs_from_rgb(r,g,b), out[i])
    end
    return table.concat(out)
end

-- Skillchain data -------------------------------------------------------------
local skillchains = {'Light','Darkness','Gravitation','Fragmentation','Distortion','Fusion','Compression','Liquefaction','Induration','Reverberation','Transfixion','Scission','Detonation','Impaction','Radiance','Umbra'}

local sc_info = {
    Radiance		= {'Fire','Wind','Lightning','Light', lvl=4},
    Umbra			= {'Earth','Ice','Water','Dark', lvl=4},
    Light			= {'Fire','Wind','Lightning','Light', Light={4,'Light','Radiance'}, lvl=3},
    Darkness		= {'Earth','Ice','Water','Dark', Darkness={4,'Darkness','Umbra'}, lvl=3},
    Gravitation		= {'Earth','Dark', Distortion={3,'Darkness'}, Fragmentation={2,'Fragmentation'}, lvl=2},
    Fragmentation	= {'Wind','Lightning', Fusion={3,'Light'}, Distortion={2,'Distortion'}, lvl=2},
    Distortion		= {'Ice','Water', Gravitation={3,'Darkness'}, Fusion={2,'Fusion'}, lvl=2},
    Fusion			= {'Fire','Light', Fragmentation={3,'Light'}, Gravitation={2,'Gravitation'}, lvl=2},
    Compression		= {'Darkness', Transfixion={1,'Transfixion'}, Detonation={1,'Detonation'}, lvl=1},
    Liquefaction	= {'Fire', Impaction={2,'Fusion'}, Scission={1,'Scission'}, lvl=1},
    Induration		= {'Ice', Reverberation={2,'Fragmentation'}, Compression={1,'Compression'}, Impaction={1,'Impaction'}, lvl=1},
    Reverberation	= {'Water', Induration={1,'Induration'}, Impaction={1,'Impaction'}, lvl=1},
    Transfixion		= {'Light', Scission={2,'Distortion'}, Reverberation={1,'Reverberation'}, Compression={1,'Compression'}, lvl=1},
    Scission		= {'Earth', Liquefaction={1,'Liquefaction'}, Reverberation={1,'Reverberation'}, Detonation={1,'Detonation'}, lvl=1},
    Detonation		= {'Wind', Compression={2,'Gravitation'}, Scission={1,'Scission'}, lvl=1},
    Impaction		= {'Lightning', Liquefaction={1,'Liquefaction'}, Detonation={1,'Detonation'}, lvl=1},
}

local chainbound = {}
chainbound[1] = L{'Compression','Detonation','Liquefaction','Induration','Impaction','Reverberation','Scission','Transfixion'}
chainbound[2] = L{'Gravitation','Fragmentation','Distortion','Fusion'} + chainbound[1]
chainbound[3] = L{'Light','Darkness'} + chainbound[2]

-- Weapon indices --------------------------------------------------------------
local prema_weapon = {
    -- Relic Weapons
    ['Spharai']={18264,18265,18637,18651,18665,19746,19839,20480,20481,20509},
    ['Mandau']={18270,18271,18638,18652,18666,19747,19840,20555,20556,20583},
    ['Excalibur']={18276,18277,18639,18653,18667,19748,19841,20645,20646,20685},
    ['Ragnarok']={18282,18283,18640,18654,18668,19749,19842,20745,20746,21683},
    ['Guttler']={18288,18289,18641,18655,18669,19750,19843,20790,20791,21750},
    ['Bravura']={18294,18295,18642,18656,18670,19751,19844,20835,20836,21756},
    ['Apocalypse']={18306,18307,18644,18658,18672,19753,19846,20880,20881,21808},
    ['Gungnir']={18300,18301,18643,18657,18671,19752,19845,20925,20926,21857},
    ['Kikoku']={18312,18313,18645,18659,18673,19754,19847,20970,20971,21906},
    ['Amanomurakumo']={18318,18319,18646,18660,18674,19755,19848,21015,21016,21954},
    ['Mjollnir']={18324,18325,18647,18661,18675,19756,19849,21060,21061,21077},
    ['Claustrum']={18330,18331,18648,18662,18676,19757,19850,21135,21136,22060},
    ['Yoichinoyumi']={18348,18349,18650,18664,18678,19759,19852,21210,21211,22115,22129},
    ['Annihilator']={18336,18337,18649,18663,18677,19758,19851,21260,21261,21267,22140},
    -- Mythic Weapons
    ['Conqueror']={18971,18991,19060,19080,19612,19710,19819,19948,20837,20838,21757},
    ['Glanzfaust']={18972,18992,19061,19081,19613,19711,19820,19949,20482,20483,20510},
    ['Yagrush']={18973,18993,19062,19082,19614,19712,19821,19950,21062,21063,21078},
    ['Laevateinn']={18974,18994,19063,19083,19615,19713,19822,19951,21139,21140,22062},
    ['Murgleis']={18975,18995,19064,19084,19616,19714,19823,19952,20647,20648,20686},
    ['Vajra']={18976,18996,19065,19085,19617,19715,19824,19953,20559,20560,20585},
    ['Burtgang']={18977,18997,19066,19086,19618,19716,19825,19954,20649,20650,20687},
    ['Liberator']={18978,18998,19067,19087,19619,19717,19826,19955,20882,20883,21809},
    ['Aymur']={18979,18999,19068,19088,19620,19718,19827,19956,20792,20793,21751},
    ['Carnwenhan']={18980,19000,19069,19089,19621,19719,19828,19957,20561,20562,20586},
    ['Gastraphetes']={18981,19001,19070,19090,19622,19720,19829,19958,21246,21247,21266,22139},
    ['Kogarasumaru']={18982,19002,19071,19091,19623,19721,19830,19959,21017,21018,21955},
    ['Nagi']={18983,19003,19072,19092,19624,19722,19831,19960,20972,20973,21907},
    ['Ryunohige']={18984,19004,19073,19093,19625,19723,19832,19961,20927,20928,21858},
    ['Nirvana']={18985,19005,19074,19094,19626,19724,19833,19962,21141,21142,22063},
    ['Tizona']={18986,19006,19075,19095,19627,19725,19834,19963,20651,20652,20688},
    ['Death Penalty']={18987,19007,19076,19096,19628,19726,19835,19964,21262,21263,21268,22141},
    ['Kenkonken']={18988,19008,19077,19097,19629,19727,19836,19965,20484,20485,20511},
    ['Terpsichore']={18969,18989,19078,19098,19630,19728,19837,19966,20557,20558,20584},
    ['Tupsimati']={18970,18990,19079,19099,19631,19729,19838,19967,21137,21138,22061},
    ['Idris']={21070,21080},
    ['Epeolatry']={20753,21685},
    -- Empyrean Weapons
    ['Verethragna']={19397,19456,19534,19632,19805,19853,20486,20487,20512},
    ['Twashtar']={19398,19457,19535,19633,19806,19854,20563,20564,20587},
    ['Almace']={19399,19458,19536,19634,19807,19855,20653,20654,20689},
    ['Caladbolg']={19400,19459,19537,19635,19808,19856,20747,20748,21684},
    ['Farsha']={19401,19460,19538,19636,19809,19857,20794,20795,21752},
    ['Ukonvasara']={19402,19461,19539,19637,19810,19858,20839,20840,21758},
    ['Redemption']={19403,19462,19540,19638,19811,19859,20884,20885,21810},
    ['Rhongomiant']={19404,19463,19541,19639,19812,19860,20929,20930,21859},
    ['Kannagi']={19405,19464,19542,19640,19813,19861,20974,20975,21908},
    ['Masamune']={19406,19465,19543,19641,19814,19862,21019,21020,21956},
    ['Gambanteinn']={19407,19466,19544,19642,19815,19863,21064,21065,21079},
    ['Hvergelmir']={19408,19467,19545,19643,19816,19864,21143,21144,22064},
    ['Gandiva']={19409,19468,19546,19644,19817,19865,21212,21213,22116,22130},
    ['Armageddon']={19410,19469,19547,19645,19818,19866,21264,21265,21269,22142},
    -- Pulse Weapons
    ['Karambit']={21519}, ['Tauret']={21565}, ['Naegling']={21621}, ['Nandaka']={21674},
    ['Dolichenus']={21722}, ['Lycurgos']={21779}, ['Drepanum']={21830}, ['Shining One']={21883},
    ['Gokotai']={21922}, ['Hachimonji']={21975}, ['Maxentius']={22031}, ['Xoanon']={22086},
    ['Ullr']={22107},
    -- Aeonic Weapons
    ['Godhands']={20515}, ['Aeneas']={20594}, ['Sequence']={20695}, ['Chango']={20843},
    ['Anguta']={20890}, ['Trishula']={20935}, ['Heishi Shorinken']={20977}, ['Dojikiri Yasutsuna']={21025},
    ['Tishtrya']={21082}, ['Khatvanga']={21147}, ['Fomalhaut']={21485,22143}, ['Lionheart']={21694},
    ['Tri-edge']={21753}, ['Fail-Not']={22117,22131},
    -- Prime Weapons
    ['Varga Purnikawa']={21532,21533,21534,21535}, ['Mpu Gandring']={21587,21588,21589,21590},
    ['Caliburnus']={21643,21644,21645,21646}, ['Helheim']={21649,21651,21652,21653},
    ['Spalirisos']={21727,21728,21729,21730}, ['Laphria']={21782,21783,21784,21785},
    ['Foenaria']={21834,21835,21836,21837}, ['Gae Buide']={21888,21889,21890,21891},
    ['Dokoku']={21929,21930,21931,21932}, ['Kusanagi']={21983,21984,21985,21986},
    ['Lorg Mor']={21998,22000,22001,22002}, ['Opashoro']={22103,22104,22105,22106},
    ['Pinaka']={22156,22157,22158,22163}, ['Earp']={22160,22161,22162,22164},
}

local aeonic_index = {}
for name, ids in pairs(prema_weapon) do
    for i = 1, #ids do
        aeonic_index[ids[i]] = name
    end
end

-- UI init --------------------------------------------------------------------
local function initialize(text, settings)
    if not windower.ffxi.get_info().logged_in then return end
    if not info.job then
        local player = windower.ffxi.get_player()
        info.job = player.main_job
        info.player = player.id
    end
    local properties = L{}
    if settings.Show.timer[info.job] then properties:append('${timer}') end
    if settings.Show.step[info.job] then properties:append('Step: ${step} → ${name}') end
    if settings.Show.props[info.job] then
        properties:append('[${props}] ${elements}')
    elseif settings.Show.burst[info.job] then
        properties:append('${elements}')
    end
    properties:append('${disp_info}')
    text:clear()
    text:append(properties:concat('\n'))
end
skill_props:register_event('reload', initialize)

-- Aeonic support --------------------------------------------------------------
local check_weapon -- coroutine ref

local function update_weapon()
    if not settings.Show.weapon[info.job] then return end

    local main = windower.ffxi.get_items(info.main_bag, info.main_weapon)
    local main_id = main and main.id or 0
    if main_id ~= 0 then
        info.aeonic = aeonic_index[main_id]
        if info.aeonic then return end
    end

    if info.range and info.range_bag then
        local r = windower.ffxi.get_items(info.range_bag, info.range)
        local range_id = r and r.id or 0
        if range_id ~= 0 then
            info.aeonic = aeonic_index[range_id]
            if info.aeonic then return end
        end
    end

    info.aeonic = nil
    if not check_weapon or coroutine.status(check_weapon) ~= 'suspended' then
        check_weapon = coroutine.schedule(update_weapon, 10)
    end
end

local function aeonic_am(step)
    for x=270,272 do
        if buffs[info.player] and buffs[info.player][x] then
            return 272-x < step
        end
    end
    return false
end

local function aeonic_prop(ability, actor)
    if ability.aeonic and ((ability.weapon == info.aeonic and actor == info.player) or (settings.aeonic and info.player ~= actor)) then
        return {ability.skillchain[1], ability.skillchain[2], ability.aeonic}
    end
    return ability.skillchain
end

-- Skillchain mechanics --------------------------------------------------------
local function check_props(old, new)
    for k = 1, #old do
        local first = old[k]
        local combo = sc_info[first]
        for i = 1, #new do
            local second = new[i]
            local result = combo[second]
            if result then
                return unpack(result)
            end
            if #old > 3 and combo.lvl == sc_info[second].lvl then
                break
            end
        end
    end
end

local function add_skills(t, abilities, active, resource, AM)
    local tt = {{},{},{},{}}
    for k=1,#abilities do
        local ability_id = abilities[k]
        local skillchain = skills[resource] and skills[resource][ability_id]
        if skillchain then
            local lv, prop, aeonic = check_props(active, aeonic_prop(skillchain, info.player))
            if prop then
                prop = AM and aeonic or prop

                local name_raw   = res[resource][ability_id].name
                local name_field = ('%-16s'):format(name_raw)
                if settings.color and info.aeonic and skillchain.weapon == info.aeonic then
                    name_field = ("%s%s\\cr"):format(AEONIC_TIER_COLOR(lv), name_field)
                end

                if settings.color then
                    local grad = prop_grad_palette[prop]
                    local prop_str = grad and grad_colorize_word(prop, grad[1], grad[2]) or ("%s%s\\cr"):format(colors[prop] or "", prop)
                    tt[lv][#tt[lv]+1] = ('%s → Lv.%d %s'):format(name_field, lv, prop_str)
                else
                    tt[lv][#tt[lv]+1] = ('%s → Lv.%d %-14s'):format(name_field, lv, prop)
                end
            end
        end
    end
    for x=4,1,-1 do
        for k=#tt[x],1,-1 do
            t[#t+1] = tt[x][k]
        end
    end
    return t
end

local function colorize(t)
    local out = {}
    if settings.color then
        for k=1,#t do
            local token = t[k]
            local grad = prop_grad_palette[token]
            if grad then
                out[#out+1] = grad_colorize_word(token, grad[1], grad[2])
            else
                out[#out+1] = ("%s%s\\cr"):format(colors[token] or '', token)
            end
        end
    else
        for k=1,#t do out[#out+1] = t[k] end
    end
    return table.concat(out, ',')
end

local function check_results(reson)
    local t = {}
    if settings.Show.spell[info.job] and info.job == 'SCH' then
        t = add_skills(t, {0,1,2,3,4,5,6,7}, reson.active, 'elements')
    elseif settings.Show.spell[info.job] and info.job == 'BLU' then
        t = add_skills(t, windower.ffxi.get_mjob_data().spells, reson.active, 'spells')
    elseif settings.Show.pet[info.job] and windower.ffxi.get_mob_by_target('pet') then
        t = add_skills(t, windower.ffxi.get_abilities().job_abilities, reson.active, 'job_abilities')
    end
    if settings.Show.weapon[info.job] then
        t = add_skills(t, windower.ffxi.get_abilities().weapon_skills, reson.active, 'weapon_skills', info.aeonic and aeonic_am(reson.step))
    end
    return _raw.table.concat(t, '\n')
end

-- Render loop ----------------------------------------------------------------
local visible
local next_frame = os.clock()

windower.register_event('prerender', function()
    local now = os.clock()
    if now < next_frame then return end
    next_frame = now + (settings.UpdateFrequency or 0.1)

    for k, v in pairs(resonating) do
        if k ~= 'preview' and (v.times - now + 10) < 0 then resonating[k] = nil end
    end
    if resonating.preview and (resonating.preview.times - now + 10) < 0 then resonating.preview = nil end

    local targ = windower.ffxi.get_mob_by_target('t', 'bt')
    local targ_id = targ and targ.id

    if targ and targ.hpp == 0 then
        if resonating[targ.id] then resonating[targ.id] = nil end
        if skill_props:visible() then skill_props:hide() end
        return
    end

    local reson = (targ_id and resonating[targ_id]) or resonating.preview
    local timer = reson and (reson.times - now) or 0

    if reson and timer > 0 then
        if not reson.closed then
            reson.disp_info = reson.disp_info or check_results(reson)
            local delay = reson.delay
            reson.timer = now < delay and '\\cs(255,0,0)Wait  %.1f\\cr':format(delay - now)
                                       or '\\cs(0,255,0)Go!   %.1f\\cr':format(timer)
        elseif settings.Show.burst[info.job] then
            reson.disp_info = ''
            reson.timer = 'Burst %d':format(timer)
        else
            if targ_id and resonating[targ_id] == reson then
                resonating[targ_id] = nil
            elseif resonating.preview == reson then
                resonating.preview = nil
            end
            return
        end
        if reson.display_name then
            reson.name = reson.display_name
        else
            reson.name = res[reson.res][reson.id].name
        end
        reson.props = reson.props or (not reson.bound and colorize(reson.active)) or ('Chainbound Lv.%d'):format(reson.bound)
        reson.elements = reson.elements or (reson.step > 1 and settings.Show.burst[info.job] and ('(%s)'):format(colorize(sc_info[reson.active[1]])) or '')
        skill_props:update(reson)
        skill_props:show()
    elseif not visible then
        skill_props:hide()
    end
end)

-- Buff helpers ----------------------------------------------------------------
local function check_buff(t, i)
    if t[i] == true or t[i] - os.time() > 0 then return true end
    t[i] = nil
end

local function chain_buff(t)
    local i = t[164] and 164 or t[470] and 470
    if i and check_buff(t, i) then t[i] = nil return true end
    return t[163] and check_buff(t, 163)
end

-- Action handling -------------------------------------------------------------
local categories = S{
    'weaponskill_finish','spell_finish','job_ability','mob_tp_finish','avatar_tp_finish','job_ability_unblinkable',
}

local function apply_preview(resource, action_id, properties, delay, step, closed, bound, display_name)
    local clock = os.clock()
    resonating.preview = {
        res=resource, id=action_id, active=properties, delay=clock+delay, times=clock+delay+8-step,
        step=step, closed=closed, bound=bound, display_name=display_name,
    }
    next_frame = clock
end

local targ_id -- forward-declared for action handler reuse

local function apply_properties(target, resource, action_id, properties, delay, step, closed, bound, display_name)
    local clock = os.clock()
    resonating[target] = {
        res=resource, id=action_id, active=properties, delay=clock+delay, times=clock+delay+8-step,
        step=step, closed=closed, bound=bound, display_name=display_name,
    }
    if target == targ_id then next_frame = clock end
end

local function action_handler(act)
    local actionpacket = ActionPacket.new(act)
    local category = actionpacket:get_category_string()
    if not categories:contains(category) or act.param == 0 then return end

    local actor   = actionpacket:get_id()
    local target  = actionpacket:get_targets()()
    local action  = target:get_actions()()
    local msg_id  = action:get_message_id()
    local add_eff = action:get_add_effect()
    local param, resource, action_id, interruption, conclusion = action:get_spell()
    local ability = skills[resource] and skills[resource][action_id]

    if add_eff and conclusion and SKILLCHAIN_IDS:contains(add_eff.message_id) then
        local skillchain = add_eff.animation:ucfirst()
        local level = sc_info[skillchain].lvl
        local reson = resonating[target.id]
        local delay = ability and ability.delay or 3
        local step = (reson and reson.step or 1) + 1
        if level == 3 and reson and ability then
            level = select(1, check_props(reson.active, aeonic_prop(ability, actor)))
        end
        local closed = step > 5 or level == 4
        apply_properties(target.id, resource, action_id, {skillchain}, delay, step, closed)

    elseif ability and (MESSAGE_IDS:contains(msg_id) or (msg_id == 2 and buffs[actor] and chain_buff(buffs[actor]))) then
        apply_properties(target.id, resource, action_id, aeonic_prop(ability, actor), ability.delay or 3, 1)

    elseif msg_id == 529 then
        apply_properties(target.id, resource, action_id, chainbound[param], 2, 1, false, param)

    elseif msg_id == 100 and BUFF_DUR[param] then
        buffs[actor] = buffs[actor] or {}
        buffs[actor][param] = BUFF_DUR[param] + os.time()
    end
end
ActionPacket.open_listener(action_handler)

-- Network hooks ---------------------------------------------------------------
windower.register_event('incoming chunk', function(id, data)
    if id == 0x29 and data:unpack('H', 25) == 206 and data:unpack('I', 9) == info.player then
        if buffs[info.player] then buffs[info.player][data:unpack('H', 13)] = nil end

    elseif id == 0x50 and data:byte(6) == 0 then
        info.main_weapon = data:byte(5)
        info.main_bag = data:byte(7)
        update_weapon()

    elseif id == 0x50 and data:byte(6) == 2 then
        info.range = data:byte(5)
        info.range_bag = data:byte(7)
        update_weapon()

    elseif id == 0x63 and data:byte(5) == 9 then
        local set_buff = {}
        for n=1,32 do
            local buff = data:unpack('H', n*2+7)
            if BUFF_DUR[buff] or (buff > 269 and buff < 273) then set_buff[buff] = true end
        end
        buffs[info.player] = set_buff
    end
end)

-- Input parsing helpers -------------------------------------------------------
local function _norm(s) return (s or ''):lower():gsub('[%s%p]+','') end
local function _auto(s) return (s and s ~= '' and windower and windower.convert_auto_trans) and windower.convert_auto_trans(s) or s end
local function _unwrap_token(s)
    if not s then return s end
    s = s:match('^%s*(.-)%s*$') or s
    local first,last = s:sub(1,1), s:sub(-1)
    local pairs = {['\"']='\"', ['{']='}', ['[']=']', ['<']='>'}
    if pairs[first] and last == pairs[first] then return s:sub(2, -2) end
    return s
end
local function _is_sc_name(s)
    if not s or s == '' then return false end
    local n = _norm(_auto(_unwrap_token(s)))
    for sc_name in pairs(sc_info) do if _norm(_auto(sc_name)) == n then return true end end
    return false
end
local function _parse_ws_sc_from_string(str)
    if not str or str == '' then return nil, nil end
    local s = _auto(str)
    local segs = {}
    for w in s:gmatch('"([^"]+)"') do segs[#segs+1] = w end
    for w in s:gmatch('{([^}]+)}') do segs[#segs+1] = w end
    if #segs >= 2 then
        if _is_sc_name(segs[1]) and not _is_sc_name(segs[2]) then return segs[2], segs[1]
        elseif _is_sc_name(segs[2]) and not _is_sc_name(segs[1]) then return segs[1], segs[2]
        else return segs[1], segs[2] end
    elseif #segs == 1 then
        return segs[1], nil
    end
    local toks = {}
    for token in s:gmatch('%S+') do toks[#toks+1] = token end
    if #toks == 0 then return nil, nil end
    if #toks == 1 then return _unwrap_token(toks[1]), nil end
    local first = _unwrap_token(toks[1])
    local last  = _unwrap_token(toks[#toks])
    if _is_sc_name(first) and not _is_sc_name(last) then
        return table.concat(toks, ' ', 2), first
    elseif _is_sc_name(last) and not _is_sc_name(first) then
        return table.concat(toks, ' ', 1, #toks-1), last
    else
        return table.concat(toks, ' '), nil
    end
end

-- Simulation (targetless) -----------------------------------------------------
local function simulate_ws_on_self(ws_query, prior_sc)
    if not windower.ffxi.get_info().logged_in then return end
    ws_query = _unwrap_token(_auto(ws_query or ''))
    prior_sc = _unwrap_token(_auto(prior_sc or ''))

    local ws_catalog = skills.weapon_skills or {}
    local ids = {}
    for id, abil in pairs(ws_catalog) do if abil then ids[#ids+1] = id end end
    if #ids == 0 then
        windower.add_to_chat(207, ('%s: no weapon skills in skills.lua.'):format(_addon.name))
        return
    end
    table.sort(ids)

    if (not prior_sc or prior_sc == '') and (ws_query and ws_query ~= '') then
        local single_norm = _norm(ws_query)
        for sc_name, _ in pairs(sc_info) do
            if _norm(_auto(sc_name)) == single_norm then prior_sc = ws_query ws_query = '' break end
        end
    end

    local ws_id
    if ws_query and ws_query ~= '' then
        local q = ws_query:match('^%s*(.-)%s*$')
        local idq = tonumber(q)
        if idq and ws_catalog[idq] then ws_id = idq end
        if not ws_id then
            local qn = _norm(q)
            local best_score, best_id = -1, nil
            for id, _ in pairs(ws_catalog) do
                local r = res.weapon_skills[id]
                if r and r.name then
                    local name = _auto(r.name)
                    local name_n = _norm(name)
                    local score = (name:lower() == q:lower() and 3000)
                               or (name_n == qn and 2000)
                               or (name:lower():find(q:lower(), 1, true) and 1000)
                               or (name_n:find(qn, 1, true) and 900)
                               or -1
                    if score > best_score then best_score, best_id = score, id end
                end
            end
            if best_id and best_score >= 0 then ws_id = best_id end
        end
        if not ws_id then
            windower.add_to_chat(207, ('%s: no match for "%s". Use exact name or ID from skills.lua.'):format(_addon.name, ws_query))
            return
        end
    else
        ws_id = ids[1]
    end

    local ability = ws_catalog[ws_id]
    if not ability then
        windower.add_to_chat(207, ('%s: WS %d missing in skills.lua.'):format(_addon.name, ws_id))
        return
    end

    local props, step, display_name
    if prior_sc and prior_sc ~= '' then
        local want = prior_sc:match('^%s*(.-)%s*$')
        local want_norm = _norm(want)
        local found
        for sc_name, _ in pairs(sc_info) do if _norm(_auto(sc_name)) == want_norm then found = sc_name break end end
        if not found then
            windower.add_to_chat(207, ('%s: unknown skillchain "%s". Valid examples: %s'):format(_addon.name, prior_sc, table.concat(skillchains, ', ')))
            return
        end
        props = {found}
        step = 2
        if not ws_query or ws_query == '' then display_name = ('[Prior SC] %s'):format(found) end
    else
        props = aeonic_prop(ability, info.player)
        step = 1
    end

    apply_preview('weapon_skills', ws_id, props, ability.delay or 3, step, nil, nil, display_name)
end

-- Commands -------------------------------------------------------------------
windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower()
    local args = {...}

    if cmd == 'move' then
        visible = not visible
        if visible and not skill_props:visible() then
            skill_props:update({disp_info='     --- SkillChains ---\n\n\n\nClick and drag to move display.'})
            skill_props:show()
        elseif not visible then
            skill_props:hide()
        end

    elseif cmd == 'save' then
        local arg = ... and ...:lower() == 'all' and 'all'
        config.save(settings, arg)
        windower.add_to_chat(207, ('%s: settings saved to %s character%s.'):format(_addon.name, arg or 'current', arg and 's' or ''))

    elseif cmd == 'colors' then
        local a = args[1] and args[1]:lower() or ''
        if a == 'on' then settings.color = true
        elseif a == 'off' then settings.color = false
        else settings.color = not settings.color end
        config.save(settings)
        config.reload(settings)
        windower.add_to_chat(207, ('%s: color %s'):format(_addon.name, settings.color and 'on' or 'off'))

    elseif default.Show[cmd] then
        if not default.Show[cmd][info.job] then return error(('unable to set %s on %s.'):format(cmd, info.job)) end
        local key = settings.Show[cmd][info.job]
        if not key then settings.Show[cmd]:add(info.job) else settings.Show[cmd]:remove(info.job) end
        config.save(settings)
        config.reload(settings)
        windower.add_to_chat(207, ('%s: %s info will no%s be displayed on %s.'):format(_addon.name, cmd, key and ' longer' or 'w', info.job))

    elseif type(default[cmd]) == 'boolean' then
        settings[cmd] = not settings[cmd]
        windower.add_to_chat(207, ('%s: %s %s'):format(_addon.name, cmd, settings[cmd] and 'on' or 'off'))

    elseif cmd == 'test' or cmd == 'simulate' then
        local raw = table.concat(args, ' ')
        local ws, sc = _parse_ws_sc_from_string(raw or '')
        simulate_ws_on_self(ws, sc)

    else
        windower.add_to_chat(207, ('%s: valid commands [save | move | test | simulate | burst | weapon | spell | pet | props | step | timer | colors (on|off|toggle) | aeonic]\nUsage:\n  sc test "weaponskill"\n  sc test "skillchain"\n  sc test "weaponskill" "skillchain"\nExamples:\n  sc test "Savage Blade"\n  sc test "Fragmentation"\n  sc test {Savage Blade} {Fragmentation}'):format(_addon.name))
    end
end)

-- Minor hooks ----------------------------------------------------------------
windower.register_event('incoming text', function(original, modified, mode)
    -- Reserved for users who wire EvaluateText/EvaluateChat. No default behavior.
    -- Leave untouched to avoid unintended triggers in release builds.
end)

windower.register_event('job change', function(job, lvl)
    local j = res.jobs:with('id', job).english_short
    if j ~= info.job then
        info.job = j
        config.reload(settings)
    end
end)

windower.register_event('zone change', function()
    resonating = {}
end)

windower.register_event('load', function()
    if windower.ffxi.get_info().logged_in then
        local equip = windower.ffxi.get_items('equipment')
        info.main_weapon = equip.main
        info.main_bag = equip.main_bag
        info.range = equip.range
        info.range_bag = equip.range_bag
        update_weapon()
        buffs[info.player] = {}
    end
end)

windower.register_event('unload', function()
    if check_weapon then coroutine.close(check_weapon) end
end)

windower.register_event('logout', function()
    if check_weapon then coroutine.close(check_weapon) end
    check_weapon = nil
    info = {}
    resonating = {}
    buffs = {}
end)
