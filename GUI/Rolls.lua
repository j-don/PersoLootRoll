local Name, Addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(Name)
local AceGUI = LibStub("AceGUI-3.0")
local GUI, Inspect, Item, Masterloot, Roll, Trade, Unit, Util = Addon.GUI, Addon.Inspect, Addon.Item, Addon.Masterloot, Addon.Roll, Addon.Trade, Addon.Unit, Addon.Util
local Self = GUI.Rolls

Self.frames = {}
Self.filter = {all = false, hidden = false, done = true, awarded = true, traded = false}
Self.status = {width = 700, height = 300}
Self.open = {}

-- Register for roll changes
Roll.On(Self, Roll.EVENT_CHANGE, function () Self.Update() end)
Roll.On(Self, Roll.EVENT_CLEAR, function (_, roll)
    Self.open[roll.id] = nil
end)

-- Register for ML changes
Masterloot.On(Self, Masterloot.EVENT_CHANGE, function () Self.Update() end)

-------------------------------------------------------
--                     Show/Hide                     --
-------------------------------------------------------

-- Show the frame
function Self.Show()
    if Self.frames.window then
        Self.frames.window.frame:Show()
    else

        -- WINDOW

        Self.frames.window = GUI("Window")
            .SetLayout(nil)
            .SetFrameStrata("MEDIUM")
            .SetTitle("PersoLootRoll - " .. L["ROLLS"])
            .SetCallback("OnClose", function (self)
                Self.status.width = self.frame:GetWidth()
                Self.status.height = self.frame:GetHeight()
                self.optionsBtn, self.versionBtn = nil, nil
                self:Release()
                wipe(Self.frames)
                wipe(Self.open)
            end)
            .SetMinResize(550, 120)
            .SetStatusTable(Self.status)()

        do
            local window = Self.frames.window

            -- Options button
            f = GUI("Icon")
                .SetImage("Interface\\Buttons\\UI-OptionsButton")
                .SetImageSize(14, 14).SetHeight(16).SetWidth(16)
                .SetCallback("OnClick", function (self)
                    Addon:ShowOptions()
                    GameTooltip:Hide()
                end)
                .SetCallback("OnEnter", function (self)
                    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
                    GameTooltip:SetText(OPTIONS, 1, 1, 1, 1)
                    GameTooltip:Show()
                end)
                .SetCallback("OnLeave", GUI.TooltipHide)
                .AddTo(window)()
            f.OnRelease = function (self)
                self.image:SetPoint("TOP", 0, -5)
                self.frame:SetFrameStrata("MEDIUM")
                self.OnRelease = nil
            end
            f.image:SetPoint("TOP", 0, -2)
            f.frame:SetParent(window.frame)
            f.frame:SetPoint("TOPRIGHT", window.closebutton, "TOPLEFT", -8, -8)
            f.frame:SetFrameStrata("HIGH")
            f.frame:Show()
            
            window.optionsBtn = f

            -- Version label
            f = GUI("InteractiveLabel")
                .SetText("v" .. Addon.VERSION)
                .SetColor(1, 0.82, 0)
                .SetCallback("OnEnter", function(self)
                    if IsInGroup() then
                        GameTooltip:SetOwner(self.frame, "ANCHOR_BOTTOMRIGHT")

                        -- Addon versions
                        local count = Util.TblCount(Addon.versions)
                        if count > 0 then
                            GameTooltip:SetText(L["TIP_ADDON_VERSIONS"])                        
                            for unit,version in pairs(Addon.versions) do
                                local name = Unit.ColoredName(Unit.ShortenedName(unit), unit)
                                local versionColor = (not version or version == Addon.VERSION) and "ffffff" or version < Addon.VERSION and "ff0000" or "00ff00"
                                GameTooltip:AddLine(("%s: |cff%s%s|r"):format(name, versionColor, version), 1, 1, 1, false)
                            end
                        end

                        -- Addon missing
                        if count + 1 < GetNumGroupMembers() then
                            GameTooltip:AddLine("\n" .. L["TIP_ADDON_MISSING"])
                            local s = ""
                            for i=1,GetNumGroupMembers() do
                                local unit = GetRaidRosterInfo(i)
                                if unit and not Addon.versions[unit] and not UnitIsUnit(unit, "player") then
                                    s = Util.StrPostfix(s, ", ") .. Unit.ColoredName(Unit.ShortenedName(unit), unit)
                                end
                            end
                            GameTooltip:AddLine(s, 1, 1, 1, true)
                        end
                        GameTooltip:Show()
                    end
                end)
                .SetCallback("OnLeave", GUI.TooltipHide)
                .AddTo(window)()
            f.OnRelease = function (self)
                self.frame:SetFrameStrata("MEDIUM")
                self.OnRelease = nil
            end
            f.frame:SetParent(window.frame)
            f.frame:SetPoint("RIGHT", window.optionsBtn.frame, "LEFT", -15, -1)
            f.frame:SetFrameStrata("HIGH")
            f.frame:Show()

            window.versionBtn = f
        end

        -- FILTER

        Self.frames.filter = GUI("SimpleGroup")
            .SetLayout(nil)
            .AddTo(Self.frames.window)
            .SetPoint("BOTTOMLEFT", 0, 0)
            .SetPoint("BOTTOMRIGHT", -25, 0)
            .SetHeight(24)()
        
        do
            f = GUI("Label")
                .SetFontObject(GameFontNormal)
                .SetText(L["FILTER"] .. ":")
                .AddTo(Self.frames.filter)
                .SetPoint("TOPLEFT")()
            f:SetWidth(f.label:GetStringWidth() + 30)
            f.label:SetPoint("TOPLEFT", 15, -6)

            for _,key in ipairs({"all", "done", "awarded", "traded", "hidden"}) do
                Self.CreateFilterCheckbox(key)
            end

            -- ML action
            f = GUI("Icon")
                .AddTo(Self.frames.filter)
                .SetCallback("OnEnter", function (self)
                    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
                    GameTooltip:SetText(L["TIP_MASTERLOOT_" .. (Masterloot.GetMasterlooter() and "STOP" or "START")])
                    GameTooltip:Show()
                end)
                .SetCallback("OnLeave", GUI.TooltipHide)
                .SetCallback("OnClick", function (self)
                    local ml = Masterloot.GetMasterlooter()
                    if ml then
                        Masterloot.SetMasterlooter(nil)
                    else 
                        GUI.ToggleMasterlootDropdown("TOPLEFT", self.frame, "CENTER")
                    end
                end)
                .SetImageSize(16, 16).SetHeight(16).SetWidth(16)
                .SetPoint("TOP", 0, -4)
                .SetPoint("RIGHT")()
            f.image:SetPoint("TOP")

            -- ML
            f = GUI("InteractiveLabel")
                .SetFontObject(GameFontNormal)
                .AddTo(Self.frames.filter)
                .SetText()
                .SetCallback("OnEnter", function (self)
                    local ml = Masterloot.GetMasterlooter()
                    if ml then
                        -- Info
                        local s = Masterloot.session
                        local timeoutBase, timeoutPerItem = s.timeoutBase or Roll.TIMEOUT, s.timeoutPerItem or Roll.TIMEOUT_PER_ITEM
                        local council = not s.council and "-" or Util(s.council).Keys().Map(function (unit)
                            return Unit.ColoredName(Unit.ShortenedName(unit), unit)
                        end).Concat(", ")()
                        local bids = L[s.bidPublic and "PUBLIC" or "PRIVATE"]
                        local votes = L[s.votePublic and "PUBLIC" or "PRIVATE"]

                        GameTooltip:SetOwner(self.frame, "ANCHOR_BOTTOM")
                        GameTooltip:SetText(L["TIP_MASTERLOOT"] .. "\n")
                        GameTooltip:AddLine(L["TIP_MASTERLOOT_INFO"]:format(Unit.ColoredName(ml), timeoutBase, timeoutPerItem, council, bids, votes), 1, 1, 1)

                        -- Players
                        GameTooltip:AddLine("\n" .. L["TIP_MASTERLOOTING"])
                        local units = Unit.ColoredName(UnitName("player"))
                        for unit,unitMl in pairs(Masterloot.masterlooting) do
                            if ml == unitMl then
                                units = units .. ", " .. Unit.ColoredName(Unit.ShortenedName(unit), unit)
                            end
                        end
                        GameTooltip:AddLine(units, 1, 1, 1, 1)

                        GameTooltip:Show()
                    end
                end)
                .SetCallback("OnLeave", GUI.TooltipHide)
                .SetCallback("OnClick", function (self, ...)
                    self:SetUserData("unit", Masterloot.GetMasterlooter())
                    GUI.UnitClick(self, ...)
                end)
                .SetHeight(12)
                .SetPoint("TOP", 0, -6)
                .SetPoint("RIGHT", f.frame, "LEFT")()
        end

        -- SCROLL

        Self.frames.scroll = GUI("ScrollFrame")
            .SetLayout("PLR_Table")
            .SetUserData("table", {space = 10})
            .AddTo(Self.frames.window)
            .SetPoint("TOPRIGHT")
            .SetPoint("BOTTOMLEFT", Self.frames.filter.frame, "TOPLEFT", 0, 8)()

        -- EMPTY MESSAGE

        Self.frames.empty = GUI("Label")
            .SetFont(GameFontNormal:GetFont(), 14)
            .SetColor(0.5, 0.5, 0.5)
            .SetText("- " .. L["ROLL_LIST_EMPTY"] .. " -")
            .AddTo(Self.frames.window)
            .SetPoint("CENTER")()

        Self.Update()
    end
end

-- Check if the frame is currently being shown
function Self.IsShown()
    return Self.frames.window and Self.frames.window.frame:IsShown()
end

-- Hide the frame
function Self.Hide()
    if Self:IsShown() then Self.frames.window.frame:Hide() end
end

-- Toggle the frame
function Self.Toggle()
    if Self:IsShown() then Self.Hide() else Self.Show() end
end

-------------------------------------------------------
--                      Update                       --
-------------------------------------------------------

-- Update the frame
function Self.Update()
    if not Self.frames.window then return end
    local f

    -- SCROLL

    local scroll = Self.frames.scroll
    local children = scroll.children
    scroll:PauseLayout()

    -- Header

    local header = {"ID", "ITEM", "LEVEL", "OWNER", "ML", "STATUS", "YOUR_BID", "WINNER"}
    if #children == 0 then
        scroll.userdata.table.columns = {20, 1, {25, 100}, {25, 100}, {25, 100}, {25, 100}, {25, 100}, {25, 100}, 6 * 20 - 4}

        for i,v in pairs(header) do
            GUI("Label").SetFontObject(GameFontNormal).SetText(Util.StrUcFirst(L[v])).SetColor(1, 0.82, 0).AddTo(scroll)
        end

        local actions = GUI("SimpleGroup")
            .SetLayout(nil)
            .SetHeight(16).SetWidth(17)
            .SetUserData("cell", {alignH = "end"})
            .AddTo(scroll)()
        local backdrop = {actions.frame:GetBackdropColor()}
        actions.frame:SetBackdropColor(0, 0, 0, 0)
        actions.OnRelease = function (self)
            self.frame:SetBackdropColor(unpack(backdrop))
            self.OnRelease = nil
        end
        
        -- Toggle all
        f = GUI.CreateIconButton("UI-MinusButton", actions, function (self)
            for i,child in pairs(scroll.children) do
                if child:GetUserData("isDetails") then child.frame:Hide() end
            end
            Self.Update()
        end)
        f.image:SetPoint("TOP", 0, 2)
        f.frame:SetPoint("TOPRIGHT")
    end

    -- Rolls

    local rolls = Util(Addon.rolls).CopyFilter(function (roll)
        return (Self.filter.all or roll.isOwner or roll.item.isOwner or roll.item:GetEligible("player"))
           and (Self.filter.hidden or roll.status >= Roll.STATUS_RUNNING and not roll.hidden)
           and (Self.filter.done or (roll.status ~= Roll.STATUS_DONE))
           and (Self.filter.awarded or not roll.winner)
           and (Self.filter.traded or not roll.traded)
    end).SortBy("id")()

    GUI(Self.frames.empty).Toggle(Util.TblCount(rolls) == 0)

    local it = Util.Iter(#header + 1)
    for _,roll in pairs(rolls) do
        -- Create the row
        if not children[it(0) + 1] then
            -- ID
            GUI("Label")
                .SetFontObject(GameFontNormal)
                .AddTo(scroll)
        
            -- Item
            GUI.CreateItemLabel(scroll)
            
            -- Ilvl
            GUI("Label")
                .SetFontObject(GameFontNormal)
                .AddTo(scroll)
        
            -- Owner, ML
            GUI.CreateUnitLabel(scroll)
            GUI.CreateUnitLabel(scroll)
        
            -- Status
            local f = GUI("Label").SetFontObject(GameFontNormal).AddTo(scroll)()
            f.OnRelease = function (self)
                self.frame:SetScript("OnUpdate", nil)
                self.OnRelease = nil
            end
        
            -- Your bid, Winner
            GUI("Label").SetFontObject(GameFontNormal).AddTo(scroll)
            GUI.CreateUnitLabel(scroll)
        
            -- Actions
            f = GUI("SimpleGroup")
                .SetLayout(nil)
                .SetHeight(16)
                .SetUserData("cell", {alignH = "end"})
                .AddTo(scroll)()
            local backdrop = {f.frame:GetBackdropColor()}
            f.frame:SetBackdropColor(0, 0, 0, 0)
            f.OnRelease = function (self)
                self.frame:SetBackdropColor(unpack(backdrop))
                self.OnRelease = nil
            end
        
            do
                local actions = f
        
                local needGreedClick = function (self, _, button)
                    local roll, bid = self:GetUserData("roll"), self:GetUserData("bid")
                    if button == "LeftButton" then
                        roll:Bid(bid)
                    elseif button == "RightButton" and roll.owner == Masterloot.GetMasterlooter() then
                        local answers = Masterloot.session["answers" .. bid]
                        if answers and #answers > 0 then
                            GUI.ToggleAnswersDropdown(roll, bid, answers, "TOPLEFT", self.frame, "CENTER")
                        end
                    end
                end 
        
                -- Need
                f = GUI.CreateIconButton("UI-GroupLoot-Dice", actions, needGreedClick, NEED, 14, 14)
                f:SetUserData("bid", Roll.BID_NEED)
                f.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                f.OnRelease = function (self)
                    self.frame:RegisterForClicks("LeftButtonUp")
                    self.OnRelease = nil
                end
        
                -- Greed
                f = GUI.CreateIconButton("UI-GroupLoot-Coin", actions, needGreedClick, GREED)
                f:SetUserData("bid", Roll.BID_GREED)
                f.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                f.OnRelease = function (self)
                    self.frame:RegisterForClicks("LeftButtonUp")
                    self.OnRelease = nil
                end
        
                -- Pass
                GUI.CreateIconButton("UI-GroupLoot-Pass", actions, function (self)
                    self:GetUserData("roll"):Bid(Roll.BID_PASS)
                end, PASS, 13, 13)
        
                -- Advertise
                GUI.CreateIconButton("UI-GuildButton-MOTD", actions, function (self)
                    self:GetUserData("roll"):Advertise(true)
                end, L["ADVERTISE"], 13, 13)
        
                -- Award randomly
                GUI.CreateIconButton("Interface\\GossipFrame\\BankerGossipIcon", actions, function (self)
                    self:GetUserData("roll"):End(true)
                end, L["AWARD_RANDOMLY"], 11, 11)
        
                -- Trade
                GUI.CreateIconButton("Interface\\GossipFrame\\VendorGossipIcon", actions, function (self)
                    self:GetUserData("roll"):Trade()
                end, TRADE, 13, 13)
        
                -- Restart
                f = GUI.CreateIconButton("UI-RotationLeft-Button", actions, function (self)
                    local dialog = StaticPopup_Show(GUI.DIALOG_ROLL_RESTART)
                    if dialog then
                        dialog.data = self:GetUserData("roll")
                    end
                end, L["RESTART"])
                f.image:SetPoint("TOP", 0, 2)
                f.image:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        
                -- Cancel
                f = GUI.CreateIconButton("CancelButton", actions, function (self)
                    local dialog = StaticPopup_Show(GUI.DIALOG_ROLL_CANCEL)
                    if dialog then
                        dialog.data = self:GetUserData("roll")
                    end
                end, CANCEL)
                f.image:SetPoint("TOP", 0, 1)
                f.image:SetTexCoord(0.2, 0.8, 0.2, 0.8)

                -- Hide
                f = GUI.CreateIconButton("Interface\\Buttons\\UI-CheckBox-Check", actions, function (self)
                    self:GetUserData("roll"):ToggleVisibility()
                end, L["SHOW_HIDE"])
                f.image:SetPoint("TOP", 0, 1)
        
                -- Toggle
                f = GUI.CreateIconButton("UI-PlusButton", actions, function (self)
                    local roll = self:GetUserData("roll")
                    local details = self:GetUserData("details")
        
                    if details:IsShown() then
                        Self.open[roll.id] = nil
                        details.frame:Hide()
                        self:SetImage("Interface\\Buttons\\UI-PlusButton-Up")
                    else
                        Self.open[roll.id] = true
                        Self.UpdateDetails(details, roll)
                        self:SetImage("Interface\\Buttons\\UI-MinusButton-Up")
                    end
                    self.parent.parent:DoLayout()
                end)
                f.image:SetPoint("TOP", 0, 2)
            end
        
            -- Details
            local details = GUI("SimpleGroup")
                .SetLayout("PLR_Table")
                .SetFullWidth(true)
                .SetUserData("isDetails", true)
                .SetUserData("cell", {colspan = 99})
                .SetUserData("table", {spaceH = 10, spaceV = 2})
                .AddTo(scroll)()
        
            do
                details.content:SetPoint("TOPLEFT", details.frame, "TOPLEFT", 8, -8)
                details.content:SetPoint("BOTTOMRIGHT", details.frame, "BOTTOMRIGHT", -8, 8)
                local layoutFinished = details.LayoutFinished
                local onWidthSet = details.OnWidthSet
                local onHeightSet = details.OnHeightSet
                details.LayoutFinished, details.OnWidthSet, details.OnHeightSet = function (self, width, height)
                    layoutFinished(self, width and width + 16 or nil, height and height + 16 or nil)
                end
                details.OnRelease = function (self)
                    self.content:SetPoint("TOPLEFT")
                    self.content:SetPoint("BOTTOMRIGHT")
                    self.LayoutFinished, self.OnWidthSet, self.OnHeightSet = layoutFinished, onWidthSet, onHeightSet
                    self.OnRelease = nil
                end

                details.frame:Hide()
            end
        end

        -- ID
        GUI(children[it()]).SetText(roll.id).Show()

        -- Item
        GUI(children[it()])
            .SetImage(roll.item.texture)
            .SetText(roll.item.link)
            .SetUserData("link", roll.item.link)
            .Show()

        -- Ilvl
        GUI(children[it()]).SetText(roll.item:GetBasicInfo().level or "-").Show()

        -- Owner
        GUI(children[it()])
            .SetText(Unit.ColoredName(Unit.ShortenedName(roll.item.owner), roll.item.owner))
            .SetUserData("unit", roll.item.owner)
            .Show()

        -- ML
        GUI(children[it()])
            .SetText(roll:HasMasterlooter() and Unit.ColoredName(Unit.ShortenedName(roll.owner), roll.owner) or "-")
            .SetUserData("unit", roll:HasMasterlooter() and roll.owner or nil)
            .Show()

        -- Status
        local f = GUI(children[it()]).Show()
        if roll.status == Roll.STATUS_RUNNING then
            f.SetUserData("roll", roll)
            .SetScript("OnUpdate", Self.OnStatusUpdate)
            .SetColor(1, 1, 0)
            Self.OnStatusUpdate(f().frame)
        else
            f.SetText(roll.traded and L["ROLL_TRADED"] or roll.winner and L["ROLL_AWARDED"] or L["ROLL_STATUS_" .. roll.status])
            .SetUserData("roll", nil)
            .SetScript("OnUpdate", nil)
            .SetColor(1, 1, 1)
        end

        -- Your Bid
        GUI(children[it()])
            .SetText(roll:GetBidName(roll.bid))
            .SetColor(GUI.GetBidColor(roll.bid))
            .Show()

        -- Winner
        GUI(children[it()])
            .SetText(roll.winner and Unit.ColoredName(Unit.ShortenedName(roll.winner), roll.winner) or "-")
            .SetUserData("unit", roll.winner or nil)
            .Show()

        -- Actions
        do
            local actions = children[it()]
            local details = children[it(0) + 1]
            local children = actions.children
            local it = Util.Iter()

            local canBid = not roll.bid and roll:UnitCanBid("player")
            local canBeAwarded = roll:CanBeAwarded(true)

            -- Need
            GUI(children[it()]).SetUserData("roll", roll).Toggle(canBid)
            -- Greed
            GUI(children[it()]).SetUserData("roll", roll).Toggle(canBid and (roll.ownerId or roll.itemOwnerId))
            -- Pass
            GUI(children[it()]).SetUserData("roll", roll).Toggle(canBid)
            -- Advertise
            GUI(children[it()]).SetUserData("roll", roll).Toggle(roll:ShouldAdvertise(true))
            -- Award randomly
            GUI(children[it()]).SetUserData("roll", roll).Toggle(roll.status == roll.STATUS_DONE and canBeAwarded and Util.TblCountExcept(roll.bids, Roll.BID_PASS) > 0)
            -- Trade
            GUI(children[it()]).SetUserData("roll", roll).Toggle(
                not roll.traded and (
                    (roll.winner and roll.item.isOwner or roll.isWinner) or
                    (roll.bid and roll.bid ~= Roll.BID_PASS and not roll.ownerId)
                )
            )
            -- Restart
            GUI(children[it()]).SetUserData("roll", roll).Toggle(roll:CanBeRestarted())
            -- Cancel
            GUI(children[it()]).SetUserData("roll", roll).Toggle(canBeAwarded)
            -- Hide
            GUI(children[it()])
                .SetImage("Interface\\Buttons\\UI-CheckBox-Check" .. (roll.hidden and "-Disabled" or ""), -.1, 1.1, -.1, 1.1)
                .SetUserData("roll", roll)
                .Toggle(roll.hidden or roll.status > Roll.STATUS_RUNNING)
            -- Toggle
            GUI(children[it()])
                .SetImage("Interface\\Buttons\\UI-" .. (Self.open[roll.id] and "Minus" or "Plus") .. "Button-Up")
                .SetUserData("roll", roll)
                .SetUserData("details", details)

            local n, prev = 0
            for i=#children,1,-1 do
                local child = children[i]
                if child:IsShown() then
                    if not prev then
                        child.frame:SetPoint("TOPRIGHT")
                    else
                        child.frame:SetPoint("TOPRIGHT", prev.frame, "TOPLEFT", -4, 0)
                    end
                    n, prev = n + 1, child
                end
            end

            GUI(actions).SetWidth(max(0, 20 * n - 4)).Show()
        end

        -- Details
        local details = children[it()]
        if Self.open[roll.id] then
            Self.UpdateDetails(details, roll)
        else
            details.frame:Hide()
        end
    end

    -- Release the rest
    while children[it()] do
        children[it(0)]:Release()
        children[it(0)] = nil
    end

    Util.TblRelease(rolls)
    scroll:ResumeLayout()
    scroll:DoLayout()

    -- FILTER

    local filter = Self.frames.filter
    local it = Util.Iter(1)

    filter.children[it()]:SetValue(Self.filter.all)
    filter.children[it()]:SetValue(Self.filter.done)
    filter.children[it()]:SetValue(Self.filter.awarded)
    filter.children[it()]:SetValue(Self.filter.traded)
    filter.children[it()]:SetValue(Self.filter.hidden)

    -- ML action
    local ml = Masterloot.GetMasterlooter()
    filter.children[it()]:SetImage(ml and "Interface\\Buttons\\UI-StopButton" or "Interface\\GossipFrame\\WorkOrderGossipIcon")

    -- ML
    GUI(filter.children[it()]).SetText(L["ML"] .. ": " .. (ml and Unit.ColoredName(Unit.ShortenedName(ml)) or ""))
end

-------------------------------------------------------
--                   Update Details                  --
-------------------------------------------------------

-- Update the details view of a row
function Self.UpdateDetails(details, roll)
    details.frame:Show()
    details:PauseLayout()
    
    local children = details.children

    -- Header

    local header = {"PLAYER", "ITEM_LEVEL", "EQUIPPED", "BID", "ROLL", "VOTES"}
    if #children == 0 then
        details.userdata.table.columns = {1, {25, 100}, {34, 100}, {25, 100}, {25, 100}, {25, 100}, 100}
        
        for i,v in pairs(header) do
            local f = GUI("Label").SetFontObject(GameFontNormal).SetText(Util.StrUcFirst(L[v])).SetColor(1, 0.82, 0)()
            if i == #header then
                f:SetUserData("cell", {colspan = 2})
            end
            details:AddChild(f)
        end

        GUI.TableRowHighlight(details, #header)
    end

    -- Players

    local canBeAwarded, canVote = roll:CanBeAwarded(true), roll:UnitCanVote()

    local players = Util(roll.item:GetEligible()).Copy().Merge(roll.bids).Map(function (val, unit)
        local t = Util.Tbl()
        t.unit = unit
        t.ilvl = roll.item:GetLevelForLocation(unit)
        t.bid = type(val) == "number" and val or nil
        t.votes = Util.TblCountOnly(roll.votes, unit)
        t.roll = roll.rolls[unit]
        return t
    end, true).List().SortBy(
        "bid",   99,  false,
        "votes", 0,   true,
        "roll",  100, true,
        "ilvl",  0,   false,
        "unit"
    )()

    local it = Util.Iter(#header)
    for _,player in pairs(players) do
        -- Create the row
        if not children[it(0) + 1] then
            -- Unit, Ilvl
            GUI.CreateUnitLabel(details)
            GUI("Label").SetFontObject(GameFontNormal).AddTo(details)
        
            -- Items
            local grp = GUI("SimpleGroup")
                .SetLayout(nil)
                .SetWidth(34).SetHeight(16)
                .SetBackdropColor(0, 0, 0, 0)
                .AddTo(details)()
            for i=1,2 do
                local f = GUI("Icon")
                    .SetCallback("OnEnter", GUI.TooltipItemLink)
                    .SetCallback("OnLeave", GUI.TooltipHide)
                    .SetCallback("OnClick", GUI.ItemClick)
                    .AddTo(grp)
                    .SetPoint(i == 1 and "LEFT" or "RIGHT")()
                f.image:SetPoint("TOP")
                f.OnRelease = function (self)
                    self.image:SetPoint("TOP", 0, -5)
                    self.OnRelease = nil
                end
            end
        
            -- Bid, Roll
            GUI("Label").SetFontObject(GameFontNormal).AddTo(details)
            GUI("Label").SetFontObject(GameFontNormal).AddTo(details)
        
            -- Votes
            GUI("Label")
                .SetFontObject(GameFontNormal)
                .SetCallback("OnEnter", function (self)
                    local roll, unit = self:GetUserData("roll"), self:GetUserData("unit")
                    if Util.TblCountOnly(roll.votes, unit) > 0 then
                        GameTooltip:SetOwner(self.frame, "ANCHOR_BOTTOM")
                        GameTooltip:SetText(L["TIP_VOTES"])
                        for toUnit,fromUnit in pairs(roll.votes) do
                            if unit == toUnit then
                                local c = Unit.Color(fromUnit)
                                GameTooltip:AddLine(Unit.ShortenedName(fromUnit), c.r, c.g, c.b, false)
                            end
                        end
                        GameTooltip:Show()
                    end
                end)
                .SetCallback("OnLeave", GUI.TooltipHide)
                .AddTo(details)
        
            -- Actions
            local f = GUI("Button")
                .SetWidth(100)
                .SetCallback("OnClick", function (self)
                    local roll = self:GetUserData("roll")
                    if roll:CanBeAwardedTo(self:GetUserData("unit"), true) then
                        roll:Finish(self:GetUserData("unit"))
                    elseif roll:UnitCanVote() then
                        roll:Vote(roll.vote ~= self:GetUserData("unit") and self:GetUserData("unit") or nil)
                    end
                end)()
            f.text:SetFont(GameFontNormal:GetFont())
            details:AddChild(f)
        end

        -- Unit
        GUI(children[it()])
            .SetText(Unit.ColoredName(Unit.ShortenedName(player.unit), player.unit))
            .SetUserData("unit", player.unit)
            .Show()

        -- Ilvl
        GUI(children[it()]).SetText(player.ilvl).Show()

        -- Items
        local f, links = children[it()]

        if roll.item.isRelic then
            links = Inspect.GetLink(player.unit, roll.item.relicType)
        elseif roll.item.isEquippable then
            links = Util.Tbl()
            for i,slot in pairs(Item.SLOTS[roll.item.equipLoc]) do
                tinsert(links, Inspect.GetLink(player.unit, slot))
            end
        end

        for i,child in pairs(f.children) do
            if links and links[i] then
                GUI(f.children[i])
                    .SetImage(Item.GetInfo(links[i], "texture"))
                    .SetImageSize(16, 16).SetWidth(16).SetHeight(16)
                    .SetUserData("link", links[i])
                    .Show()
            else
                child.frame:Hide()
            end
        end

        if not roll.item.isRelic then
            Util.TblRelease(links)
        end

        -- Bid
        GUI(children[it()])
            .SetText(roll:GetBidName(player.bid))
            .SetColor(GUI.GetBidColor(player.bid))
            .Show()

        -- Roll
        GUI(children[it()])
            .SetText(player.roll and Util.NumRound(player.roll) or "-")
            .Show()

        -- Votes
        GUI(children[it()])
            .SetText(player.votes > 0 and player.votes or "-")
            .SetUserData("roll", roll)
            .SetUserData("unit", player.unit)
            .Show()

        -- Actions
        local txt = canBeAwarded and L["AWARD"]
            or canVote and (roll.vote == player.unit and L["VOTE_WITHDRAW"] or L["VOTE"])
            or "-"
        GUI(children[it()])
            .SetText(txt)
            .SetDisabled(not (canBeAwarded or canVote))
            .SetUserData("unit", player.unit)
            .SetUserData("roll", roll)
            .Show()
    end

    -- Release the rest
    while children[it()] do
        children[it(0)]:Release()
        children[it(0)] = nil
    end

    Util.TblRelease(1, players)
    details:ResumeLayout()
end

-------------------------------------------------------
--                      Helpers                      --
-------------------------------------------------------

-- Create a filter checkbox
function Self.CreateFilterCheckbox(key)
    local parent = Self.frames.filter

    f = GUI("CheckBox")
        .SetLabel(L["FILTER_" .. key:upper()])
        .SetCallback("OnValueChanged", function (self, _, checked)
            if Self.filter[key] ~= checked then
                Self.filter[key] = checked
                Self.Update()
            end
        end)
        .SetCallback("OnEnter", function (self)
            GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(L["FILTER_" .. key:upper()])
            GameTooltip:AddLine(L["FILTER_" .. key:upper() .. "_DESC"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        .SetCallback("OnLeave", GUI.TooltipHide)
        .AddTo(parent)
        .SetPoint("TOPLEFT", parent.children[#parent.children-1].frame, "TOPRIGHT")()
    f:SetWidth(f.text:GetStringWidth() + 24 + 15)
    return f
end

-- Roll status OnUpdate callback
function Self.OnStatusUpdate(frame)
    GUI(frame.obj).SetText(L["SECONDS"]:format(frame.obj:GetUserData("roll"):GetTimeLeft()))
end