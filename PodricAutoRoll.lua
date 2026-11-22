local addonName = ...
local function range(a,b)
    local t = {}; for i=a,b do t[#t+1]=i end; return t
end
local presets = {
    {key='orb', label='Righteous Orb', ids={12811}, default='Need'},
    {key='minion', label="Minion's Scourgestone", ids={12840}, default='Need'},
    {key='invader', label="Invader's Scourgestone", ids={12841}, default='Need'},
    {key='corruptor', label="Corruptor's Scourgestone", ids={12843}, default='Need'},
    {key='coins', label="Zul'Gurub coins (9)", ids=range(19698,19706), default='Greed'},
    {key='bijous', label="Zul'Gurub bijous (9)", ids=range(19707,19715), default='Greed'},
    {key='argent', label='Argent Dawn turn-in materials (5)', ids={22525,22526,22527,22528,22529}, default='Greed'},
    {key='scarabs', label='AQ scarabs (8)', ids=range(20858,20865), default='Greed'},
    {key='idols', label='AQ idols (8)', ids=range(20866,20873), default='Manual'},
    {key='rune', label='Dark Rune', ids={20520}, default='Manual'},
    {key='diamond', label='Black Diamond / Pristine (2)', ids={11754,18335}, default='Manual'},
}
local modes={'Manual','Greed','Need','Pass'}
local rollTypes={Need=1, Greed=2, Pass=0}
local colors={Manual='aaaaaa',Greed='ffd15a',Need='76dc85',Pass='ff8585'}
local presetByID={}
for _,p in ipairs(presets) do for _,id in ipairs(p.ids) do presetByID[id]=p end end
local db, panel, refresh
local settingsCategory, legacySettings
local settingsName = "Podric AutoRoll"
local active={}
local warned=false
local function say(s)
    print('|cffef8999Podric AutoRoll:|r '..s)
end
local function validMode(s) return s=='Manual' or rollTypes[s]~=nil end
local function itemID(s)
    if type(s)~='string' then return nil end
    if issecretvalue and issecretvalue(s) then return nil end
    local id=tonumber(s:match('item:(%d+)') or s:match('^%s*(%d+)%s*$'))
    if id and id>0 and id<=2147483647 and id==math.floor(id) then return id end
end
local function init()
    if type(PodricAutoRollDB)~='table' then PodricAutoRollDB={} end
    db=PodricAutoRollDB
    if type(db.enabled)~='boolean' then db.enabled=true end
    if type(db.confirm)~='boolean' then db.confirm=true end
    if type(db.chat)~='boolean' then db.chat=true end
    if type(db.presets)~='table' then db.presets={} end
    if type(db.custom)~='table' then db.custom={} end
    for _,p in ipairs(presets) do
        if not validMode(db.presets[p.key]) then db.presets[p.key]=p.default end
    end
    for id,r in pairs(db.custom) do
        if type(id)~='number' or type(r)~='table' or not validMode(r.mode) then db.custom[id]=nil end
    end
end
local function rule(id)
    local r=db.custom[id]
    if r then return r.mode end
    local p=presetByID[id]
    return p and db.presets[p.key] or 'Manual'
end
local function safeValue(v)
    return not (issecretvalue and issecretvalue(v))
end
local function handleRoll(rollID,rollTime)
    if not db or not db.enabled or not safeValue(rollID) or type(rollID)~='number' or active[rollID] then return end
    if type(GetLootRollItemLink)~='function' or type(GetLootRollItemInfo)~='function' or type(RollOnLoot)~='function' then
        if not warned then warned=true; say('Loot API unavailable; leaving all rolls manual.') end
        return
    end
    local link=GetLootRollItemLink(rollID)
    local id=itemID(link)
    if not id then return end
    local mode=rule(id)
    local roll=rollTypes[mode]
    if roll==nil then return end
    local _,name,_,_,_,canNeed,canGreed=GetLootRollItemInfo(rollID)
    if not safeValue(name) or not name then return end
    if roll==1 and (not safeValue(canNeed) or not canNeed or canNeed==0) then return end
    if roll==2 and (not safeValue(canGreed) or not canGreed or canGreed==0) then return end
    local token={id=id,roll=roll,confirmed=false}
    active[rollID]=token -- Set before RollOnLoot: the confirmation event can fire synchronously.
    local lifetime=120
    if safeValue(rollTime) and type(rollTime)=='number' then lifetime=math.max(5,math.min(180,rollTime/1000+5)) end
    C_Timer.After(lifetime,function() if active[rollID]==token then active[rollID]=nil end end)
    local ok,err=pcall(RollOnLoot,rollID,roll)
    if not ok then active[rollID]=nil; error(err) end
    if db.chat then say(mode..' requested on '..link) end
end
local function handleConfirm(rollID,roll)
    if not db or not db.enabled or not db.confirm or not safeValue(rollID) or not safeValue(roll) then return end
    local token=active[rollID]
    if not token or token.confirmed or token.roll~=roll or (roll~=1 and roll~=2) then return end
    if type(ConfirmLootRoll)~='function' or type(GetLootRollItemLink)~='function' then return end
    if itemID(GetLootRollItemLink(rollID))~=token.id or rollTypes[rule(token.id)]~=roll then return end
    token.confirmed=true
    ConfirmLootRoll(rollID,roll)
end
local function cycle(mode,backwards)
    for i,v in ipairs(modes) do if v==mode then return modes[(i-1+(backwards and -1 or 1))%#modes+1] end end
    return 'Manual'
end
local function setModeText(b,mode) b:SetText('|cff'..colors[mode]..mode..'|r') end
local function label(parent,text,size)
    local f=parent:CreateFontString(nil,'ARTWORK',size or 'GameFontNormal'); f:SetText(text); f:SetJustifyH('LEFT'); return f
end
local function button(parent,text,w,h)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate'); b:SetSize(w,h or 24); b:SetText(text); return b
end
local function check(parent,text,key,x,y)
    local c=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate'); c:SetSize(24,24); c:SetPoint('TOPLEFT',x,y)
    local t=label(parent,text,'GameFontHighlightSmall'); t:SetPoint('LEFT',c,'RIGHT',2,0)
    c:SetChecked(db[key]); c:SetScript('OnClick',function(self) db[key]=not not self:GetChecked() end)
    return c
end
local function createPanel(embedded)
    if embedded then
        panel=CreateFrame('Frame','PodricAutoRollPanel')
        panel.name=settingsName
        panel:Hide()
        panel:SetSize(510,565)
    else
        panel=CreateFrame('Frame','PodricAutoRollPanel',UIParent,'BackdropTemplate')
        panel:SetSize(510,565); panel:SetPoint('CENTER'); panel:SetFrameStrata('DIALOG'); panel:SetClampedToScreen(true)
        panel:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=5,right=5,top=5,bottom=5}})
        panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag('LeftButton')
        panel:SetScript('OnDragStart',panel.StartMoving); panel:SetScript('OnDragStop',panel.StopMovingOrSizing)
        local close=CreateFrame('Button',nil,panel,'UIPanelCloseButton'); close:SetPoint('TOPRIGHT',-5,-5)
        tinsert(UISpecialFrames,'PodricAutoRollPanel')
    end
    local title=label(panel,'Podric AutoRoll  |cffaaaaaav0.1.1-beta|r','GameFontNormalLarge'); title:SetPoint('TOPLEFT',20,-18)
    local enabled=check(panel,'Enable automatic rolls','enabled',17,-43)
    local confirm=check(panel,'Confirm binding on auto-rolls','confirm',17,-67)
    local chat=check(panel,'Chat notices','chat',310,-43)
    local note=label(panel,'Click a rule to cycle: Manual > Greed > Need > Pass.','GameFontHighlightSmall'); note:SetPoint('TOPLEFT',22,-99)
    local caution=label(panel,'Use Need only when agreed. Unlisted items stay manual.','GameFontHighlightSmall'); caution:SetTextColor(1,.78,.48); caution:SetPoint('TOPLEFT',22,-115)
    local scroll=CreateFrame('ScrollFrame',nil,panel,'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',22,-139); scroll:SetPoint('BOTTOMRIGHT',-39,91)
    local content=CreateFrame('Frame',nil,scroll); content:SetSize(445,360); scroll:SetScrollChild(content)
    local rows={}
    local function makeRow(i)
        local r=CreateFrame('Frame',nil,content); r:SetSize(445,27); r:SetPoint('TOPLEFT',0,-(i-1)*27)
        r.name=label(r,'','GameFontHighlight'); r.name:SetPoint('LEFT',2,0); r.name:SetWidth(295); r.name:SetWordWrap(false)
        r.mode=button(r,'Manual',95,23); r.mode:SetPoint('RIGHT',r,'RIGHT',-27,0); r.mode:RegisterForClicks('LeftButtonUp','RightButtonUp')
        r.remove=button(r,'X',25,23); r.remove:SetPoint('RIGHT',r,'RIGHT',0,0)
        return r
    end
    refresh=function()
        enabled:SetChecked(db.enabled); confirm:SetChecked(db.confirm); chat:SetChecked(db.chat)
        local i=0
        local function row(text,mode,change,remove)
            i=i+1; local r=rows[i]; if not r then r=makeRow(i); rows[i]=r end
            r.name:SetText(text); setModeText(r.mode,mode)
            r.mode:SetScript('OnClick',function(_,mouse) change(cycle(mode,mouse=='RightButton')); refresh() end)
            if remove then r.remove:Show(); r.remove:SetScript('OnClick',function() remove(); refresh() end) else r.remove:Hide(); r.remove:SetScript('OnClick',nil) end
            r:Show()
        end
        for _,p in ipairs(presets) do
            local key=p.key
            row(p.label,db.presets[key],function(mode) db.presets[key]=mode end)
        end
        local ids={}; for id in pairs(db.custom) do ids[#ids+1]=id end; table.sort(ids)
        for _,id in ipairs(ids) do
            local r=db.custom[id]; local display=r.name
            if C_Item and C_Item.GetItemNameByID then display=C_Item.GetItemNameByID(id) or display end
            row((presetByID[id] and '* ' or '')..(display or ('Item '..id)),r.mode,function(mode) db.custom[id].mode=mode end,function() db.custom[id]=nil end)
        end
        for j=i+1,#rows do rows[j]:Hide() end
        content:SetHeight(math.max(1,i*27))
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,content:GetHeight()-scroll:GetHeight())))
    end
    local edit=CreateFrame('EditBox',nil,panel,'InputBoxTemplate'); edit:SetSize(335,25); edit:SetPoint('BOTTOMLEFT',26,55); edit:SetAutoFocus(false); edit:SetFontObject('ChatFontNormal'); edit:SetMaxLetters(1024)
    local hint=label(panel,'Shift-click an item here, paste its link, or enter its ID.','GameFontHighlightSmall'); hint:SetPoint('BOTTOMLEFT',22,32)
    local add=button(panel,'Add item',105); add:SetPoint('LEFT',edit,'RIGHT',12,0)
    local function addRule()
        local text=edit:GetText(); local id=itemID(text)
        if not id then say('Enter a numeric item ID or a valid item link.'); return end
        local name=text:match('|h%[([^%]]+)%]|h')
        if not db.custom[id] then db.custom[id]={name=name or ('Item '..id),mode=rule(id)} end
        edit:SetText(''); edit:ClearFocus(); refresh(); scroll:SetVerticalScroll(math.max(0,content:GetHeight()-scroll:GetHeight()))
    end
    add:SetScript('OnClick',addRule); edit:SetScript('OnEnterPressed',addRule); edit:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    if type(ChatEdit_InsertLink)=='function' and type(hooksecurefunc)=='function' then
        hooksecurefunc('ChatEdit_InsertLink',function(link) if panel:IsShown() and edit:HasFocus() and itemID(link) then edit:SetText(link) end end)
    end
    local footer=label(panel,'* Custom item rules override presets. X removes a custom rule.','GameFontHighlightSmall'); footer:SetPoint('BOTTOMLEFT',22,16)
    panel:SetScript('OnShow',refresh)
    panel:SetScript('OnHide',function() edit:ClearFocus() end)
    refresh()
end
local function registerSettings()
    if panel then return end
    if Settings and type(Settings.RegisterCanvasLayoutCategory)=='function'
       and type(Settings.RegisterAddOnCategory)=='function' and type(Settings.OpenToCategory)=='function' then
        createPanel(true)
        settingsCategory=Settings.RegisterCanvasLayoutCategory(panel,settingsName)
        Settings.RegisterAddOnCategory(settingsCategory)
    elseif type(InterfaceOptions_AddCategory)=='function' and type(InterfaceOptionsFrame_OpenToCategory)=='function' then
        createPanel(true)
        InterfaceOptions_AddCategory(panel)
        legacySettings=true
    end
end
local function slash(msg)
    if not db then return end
    msg=(msg or ''):lower():match('^%s*(.-)%s*$')
    if msg=='off' or msg=='on' then db.enabled=msg=='on'; if refresh then refresh() end; say(db.enabled and 'Enabled.' or 'Disabled.'); return end
    if not panel then registerSettings() end
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    elseif legacySettings then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    elseif not panel then createPanel(false); panel:Show()
    elseif panel:IsShown() then panel:Hide() else panel:Show() end
end
SLASH_PODRICAUTOROLL1='/par'
SLASH_PODRICAUTOROLL2='/podricautoroll'
SlashCmdList.PODRICAUTOROLL=slash
local f=CreateFrame('Frame')
f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('START_LOOT_ROLL')
f:RegisterEvent('CONFIRM_LOOT_ROLL')
f:RegisterEvent('CANCEL_LOOT_ROLL')
f:RegisterEvent('CANCEL_ALL_LOOT_ROLLS')
f:SetScript('OnEvent',function(_,event,a,b)
    if event=='ADDON_LOADED' then if a==addonName then init(); f:UnregisterEvent('ADDON_LOADED') end; return end
    if event=='PLAYER_LOGIN' then
        f:UnregisterEvent('PLAYER_LOGIN')
        if db then registerSettings() end
        return
    end
    local ok,err=pcall(function()
        if event=='START_LOOT_ROLL' then handleRoll(a,b)
        elseif event=='CONFIRM_LOOT_ROLL' then handleConfirm(a,b)
        elseif event=='CANCEL_LOOT_ROLL' then if safeValue(a) and a~=nil then active[a]=nil end
        elseif event=='CANCEL_ALL_LOOT_ROLLS' then active={} end
    end)
    if not ok and not warned then warned=true; say('A loot API call failed; affected roll left to the normal game UI. '..tostring(err)) end
end)
