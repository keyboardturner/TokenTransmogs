local strmatch = string.match;
local GetAllAppearanceSources = C_TransmogCollection.GetAllAppearanceSources;
local GetAppearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo;
local PlayerHasTransmogItemModifiedAppearance = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance;

--[[
-- debug, do not add to final version
local idEditBox = CreateFrame("EditBox", "AppearanceIDEditBox", UIParent, "InputBoxTemplate");
idEditBox:SetSize(500, 45);
idEditBox:SetAutoFocus(false);
idEditBox:Hide();
idEditBox:SetPoint("CENTER", UIParent, "CENTER");
idEditBox:SetTextInsets(10, 10, 10, 10);
idEditBox:SetFontObject("GameFontHighlight");
idEditBox:SetScript("OnEscapePressed", function(self) self:Hide() end);

local collectedAppearanceIDs = {};

idEditBox:SetScript("OnHide", function(self)
	collectedAppearanceIDs = {};
end)
local function _OnTooltipSetItem(tooltip)
	local _, itemLink = GameTooltip:GetItem();
	if not itemLink then return end;

	local itemAppearanceID, itemModifiedAppearanceID = C_TransmogCollection.GetItemInfo(itemLink);

	if not itemAppearanceID or not itemModifiedAppearanceID then return end;
	tooltip:AddDoubleLine("AppearanceID", itemAppearanceID);
	tooltip:AddDoubleLine("ModifiedAppearanceID", itemModifiedAppearanceID);

	local msg = string.format("AppearanceID: %d, ModifiedAppearanceID: %d", itemAppearanceID, itemModifiedAppearanceID);
	DEFAULT_CHAT_FRAME:AddMessage(msg);

	if not collectedAppearanceIDs[itemAppearanceID] then
		table.insert(collectedAppearanceIDs, itemAppearanceID);
		collectedAppearanceIDs[itemAppearanceID] = true;
	end

	local displayText = table.concat(collectedAppearanceIDs, " ");
	idEditBox:SetText(displayText);
	idEditBox:HighlightText();
	idEditBox:Show();
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, _OnTooltipSetItem);
-- end of debug
--]]


local itemData = {};

local ClassListTbl = LocalizedClassList();

local function MatchClassIcon(className)
	for k, v in pairs(ClassListTbl) do
		if v == className then
			local coords = CLASS_ICON_TCOORDS[k];
			return coords
		end
	end
end

local function GetItemClassRequirement(itemLink)
	local data = C_TooltipInfo.GetHyperlink(itemLink)
	local pattern = ITEM_CLASSES_ALLOWED:gsub("%%s", "(.+)")

	for k, v in pairs(data.lines) do
		for key, var in pairs(v) do
			if key == "leftText" and type(var) == "string" then
				local classNameFromString = strmatch(var, pattern);
				if classNameFromString then
					return MatchClassIcon(classNameFromString)
				end
			end
		end
	end
end


local ClassVisual = {};

function ClassVisual:GetClassIconMarkup(classID)
	if not self.classIconMarkups then
		self.classIconMarkups = {};
	end

	if self.classIconMarkups[classID] == nil then
		local _, fileName = GetClassInfo(classID);

		local useAtlas = false;		--CharacterCreateIcons are 128x128 they doesn't look good when down-scaled
		local iconSize = 0;			--0: follow font size

		if useAtlas then
			local atlas = "classicon-"..fileName;
			if C_Texture.GetAtlasInfo(atlas) then
				self.classIconMarkups[classID] = string.format("|A:%s:%s:%s|a", atlas, iconSize, iconSize);
			else
				self.classIconMarkups[classID] = false;
			end
		else
			self.classIconMarkups[classID] = string.format("|Tinterface\\icons\\classicon_%s:%s:%s:0:0:64:64:4:60:4:60|t", fileName, iconSize, iconSize);
		end
	end

	return self.classIconMarkups[classID]
end


local ItemContextNameTranslator = EnumUtil.GenerateNameTranslation(Enum.ItemCreationContext);

local function GetItemContextFromLink(itemLink)
	if not itemLink then return end;
	local _, linkData = LinkUtil.ExtractLink(itemLink);
	--DevTools_Dump(strsplittable(":", linkData));
	local itemContext = select(12, strsplit(":", linkData));
	itemContext = tonumber(itemContext);
	if not itemContext then return end;
	return itemContext;
end

local function GetCollectionInfoForToken(itemLink)
	if not itemLink then return end;
	local tokenID = tonumber(strmatch(itemLink, "item:(%d+)"));
	local itemInfo = tokenID and itemData[tokenID];
	if itemInfo then
		local itemContext = GetItemContextFromLink(itemLink);
		if not itemContext then return end;
		local difficultyName = ItemContextNameTranslator(itemContext);
		local appearances = itemInfo.Items[itemContext];
		if not appearances then return end;

		local classGroup = itemInfo.Classes;
		local linkReceived = true;

		local collectionInfo = {};

		for i, appearanceID in ipairs(appearances) do
			local sources = GetAllAppearanceSources(appearanceID);
			if not sources then return end

			local displayLink = select(6, GetAppearanceSourceInfo(sources[1]));
			if displayLink then
				if not strmatch(displayLink, "%[(.+)%]") then
					linkReceived = false;
				end
			end

			local classID = classGroup and classGroup[i] or nil;
			local iconMarkup = ""
			if classID then
				local baseClassID, tag = classID, nil
				if type(classID) == "string" then
					baseClassID, tag = string.match(classID, "^(%d+)%-(%w+)")
					baseClassID = tonumber(baseClassID)
				else
					baseClassID = classID
				end

				if baseClassID then
					iconMarkup = ClassVisual:GetClassIconMarkup(baseClassID) or ""
				end

				if tag == "pvp" then
					iconMarkup = iconMarkup .. " |A:questlog-questtypeicon-pvp:15:15|a"
				end
			end
			if not iconMarkup then
				local requiredClass = GetItemClassRequirement(displayLink);
				if not requiredClass then
					iconMarkup = "";
				else
					iconMarkup = "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:15:15:0:0:512:512:".. requiredClass[1]*512 ..":".. requiredClass[2]*512 ..":".. requiredClass[3]*512 ..":".. requiredClass[4]*512 .."|t"
				end
			end

			local collected = false;
			for _, sourceID in ipairs(sources) do
				if PlayerHasTransmogItemModifiedAppearance(sourceID) then
					collected = true;
					break
				end
			end

			local collectedColor = collected and GREEN_FONT_COLOR or RED_FONT_COLOR;
			local collectedText = collected and COLLECTED or FOLLOWERLIST_LABEL_UNCOLLECTED;
			collectedText = collectedColor:WrapTextInColorCode(collectedText);

			collectionInfo[i] = {
				classID = classID,
				link = displayLink,
				collected = collected,
				leftText = iconMarkup .. " " .. displayLink,
				rightText = collectedText
			};
		end

		return collectionInfo, linkReceived
	end
end

KBTUI_GetCollectionInfoForToken = GetCollectionInfoForToken;	--Globals

local function OnTooltipSetItem(tooltip)
	if not tooltip or not tooltip.GetItem then return end;		--Change GameTooltip to tooltip so it covers ItemRefTooltip
	local _, itemLink = tooltip:GetItem();
	if not itemLink then return end;

	local collectionInfo, linkReceived = GetCollectionInfoForToken(itemLink);
	if collectionInfo then
		for _, info in ipairs(collectionInfo) do
			tooltip:AddDoubleLine(info.leftText, info.rightText);
		end

		if not linkReceived then
			if tooltip.RefreshDataNextUpdate then
				tooltip:RefreshDataNextUpdate();
			end
		end

		tooltip:Show();
	end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem);




local RAID_FINDER = Enum.ItemCreationContext.RaidFinder;
local RAID_NORMAL = Enum.ItemCreationContext.RaidNormal;
local RAID_HEROIC = Enum.ItemCreationContext.RaidHeroic;
local RAID_MYTHIC = Enum.ItemCreationContext.RaidMythic;
local RAID_FINDER_EXT = Enum.ItemCreationContext.RaidFinderExtended;
local RAID_NORMAL_10 = Enum.ItemCreationContext.RaidFinder;
local RAID_NORMAL_25 = Enum.ItemCreationContext.RaidHeroic;
local QUESTREWARD =  Enum.ItemCreationContext.QuestReward;
local RAID_HEROIC_EXT = Enum.ItemCreationContext.RaidHeroicExtended;
local LegendaryCrafting_6 = Enum.ItemCreationContext.LegendaryCrafting_6; -- Warbound Normal Nerubar
local LegendaryCrafting_5 = Enum.ItemCreationContext.LegendaryCrafting_5; -- Warbound Normal Undermine


--SLs/Dragonflight+
local CLASS_GROUP_1 = {6, 9, 12};		--Death Knight, Warlock, Demon Hunter
local CLASS_GROUP_2 = {3, 8, 11};		--Hunter, Mage, Druid
local CLASS_GROUP_3 = {2, 5, 7};		--Paladin, Priest, Shaman
local CLASS_GROUP_4 = {1, 4, 10, 13};	--Warrior, Rogue, Monk, Evoker

--TBC(Mount Hyjal)-MoP
local CLASS_GROUP_5 = {2, 5, 9};		--Paladin, Priest, Warlock
local CLASS_GROUP_6 = {1, 3, 7, 10};	--Warrior, Hunter, Shaman, Monk
local CLASS_GROUP_7 = {4, 6, 8, 11};	--Rogue, Death Knight, Mage, Druid

--TBC(Gruul's Lair)-TBC(The Eye)
local CLASS_GROUP_8 = {2, 4, 7};		--Paladin, Rogue, Shaman
local CLASS_GROUP_9 = {1, 5, 11};		--Warrior, Priest, Druid
local CLASS_GROUP_10 = {3, 8, 9};		--Hunter, Mage, Warlock

--Vanilla(AQ40)
local CLASS_GROUP_11 = {1, 3, 4, 5};		--Warrior, Hunter, Rogue, Priest 			(Qiraji Bindings of Command)
local CLASS_GROUP_12 = {2, 7, 8, 9, 11};	--Paladin, Shaman, Mage, Warlock, Druid		(Qiraji Bindings of Dominance)
local CLASS_GROUP_13 = {1, 3, 4, 7, 11};	--Paladin, Hunter, Rogue, Shaman, Druid		(Vek'lore's Diadem)
local CLASS_GROUP_14 = {1, 5, 8, 9};		--Warrior, Priest, Mage, Warlock			(Vek'nilash's Circlet)
local CLASS_GROUP_15 = {1, 4, 5, 8};		--Warrior, Rogue, Priest, Mage				(Ouro's Intact Hide)
local CLASS_GROUP_16 = {2, 3, 7, 11};		--Paladin, Hunter, Shaman, Warlock, Druid	(Skin of the Great Sandworm)
local CLASS_GROUP_17 = {1, 2, 3, 4, 7};		--Warrior, Paladin, Hunter, Rogue, Shaman	(Carapace of the Old God)
local CLASS_GROUP_18 = {5, 8, 9, 11};		--Priest, Mage, Warlock, Druid				(Husk of the Old God)

--Vanilla(AQ10)
local CLASS_GROUP_19 = {3, 4, 5, 9};		--Hunter, Rogue, Priest, Warlock			(Qiraji Ceremonial Ring)
local CLASS_GROUP_20 = {1, 2, 7, 8, 11};	--Warrior, Paladin, Shaman, Mage, Druid		(Qiraji Magisterial Ring)
local CLASS_GROUP_21 = {1, 4, 5, 8};		--Warrior, Rogue, Priest, Mage				(Qiraji Martial Drape)
local CLASS_GROUP_22 = {2, 3, 7, 9, 11};	--Paladin, Hunter, Shaman, Warlock, Druid	(Qiraji Regal Drape)
local CLASS_GROUP_23 = {5, 8, 9, 11};		--Priest, Mage, Warlock, Druid				(Qiraji Ornate Hilt)
local CLASS_GROUP_24 = {1, 2, 3, 4, 7};		--Warrior, Paladin, Hunter, Rogue, Shaman	(Qiraji Spiked Hilt)

--Hyjal/Black Temple/Sunwell + PvP Season 3
local CLASS_GROUP_25 = {4, "4-pvp", 8, "8-pvp", 11, "11-pvp"};		--Rogue, Rogue, Mage, Mage, Druid, Druid				(PvE+PvP)
local CLASS_GROUP_26 = {2, "2-pvp", 5, "5-pvp", 9, "9-pvp"};		--Paladin, Paladin, Priest, Priest, Warlock, Warlock	(PvE+PvP)
local CLASS_GROUP_30 = {1, "1-pvp", 3, "3-pvp", 7, "7-pvp"};		-- Warrior, Warrior, Hunter, Hunter, Shaman, Shaman		(PvE+PvP)

-- Karazhan/Gruul/Mag/SSC/Eye + PvP Season 1/2
local CLASS_GROUP_27 = {2, "2-pvp", 4, "4-pvp", 7, "7-pvp"};		--Paladin, Paladin, Rogue, Rogue, Shaman, Shaman		(PvE+PvP)
local CLASS_GROUP_28 = {1, "1-pvp", 5, "5-pvp", 11, "11-pvp"};		--Warrior, Warrior, Priest, Priest, Druid, Druid		(PvE+PvP)
local CLASS_GROUP_29 = {3, "3-pvp", 8, "8-pvp", 9, "9-pvp"};		--Hunter, Hunter, Mage, Mage, Warlock, Warlock			(PvE+PvP)




itemData = {
	-- Sepulcher of the First Ones

	-- Helm
	-- Death Knight, Warlock, Demon Hunter
	[191005] = {
		Items = {
			[RAID_FINDER] = {
				56967, 55996, 56275,
			},
			[RAID_NORMAL] = {
				56994, 56023, 56309,
			},
			[RAID_HEROIC] = {
				56985, 56014, 56293,
			},
			[RAID_MYTHIC] = {
				56976, 56005, 56284,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[191002] = {
		Items = {
			[RAID_FINDER] = {
				56329, 56634, 56169,
			},
			[RAID_NORMAL] = {
				56356, 56664, 56199,
			},
			[RAID_HEROIC] = {
				56347, 56654, 56189,
			},
			[RAID_MYTHIC] = {
				56338, 56624, 56179,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[191003] = {
		Items = {
			[RAID_FINDER] = {
				57077, 55872, 56755,
			},
			[RAID_NORMAL] = {
				57104, 55902, 56728,
			},
			[RAID_HEROIC] = {
				57095, 55892, 56764,
			},
			[RAID_MYTHIC] = {
				57086, 55882, 56746,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk
	[191004] = {
		Items = {
			[RAID_FINDER] = {
				56383, 56047, 56494,
			},
			[RAID_NORMAL] = {
				56410, 57003, 56521,
			},
			[RAID_HEROIC] = {
				56401, 56063, 56512,
			},
			[RAID_MYTHIC] = {
				56392, 56087, 56503,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	--Shoulder
	-- Death Knight, Warlock, Demon Hunter
	[191006] = {
		Items = {
			[RAID_FINDER] = {
				56968, 55997, 56276,
			},
			[RAID_NORMAL] = {
				56995, 56024, 56310,
			},
			[RAID_HEROIC] = {
				56986, 56015, 56294,
			},
			[RAID_MYTHIC] = {
				56977, 56006, 56285,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[191007] = {
		Items = {
			[RAID_FINDER] = {
				56330, 56635, 56170, 
			},
			[RAID_NORMAL] = {
				56357, 56665, 56200, 
			},
			[RAID_HEROIC] = {
				56348, 56655, 56190,
			},
			[RAID_MYTHIC] = {
				56339, 56625, 56180,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[191008] = {
		Items = {
			[RAID_FINDER] = {
				57078, 55873, 56756, 
			},
			[RAID_NORMAL] = {
				57105, 55903, 56729, 
			},
			[RAID_HEROIC] = {
				57096, 55893, 56765, 
			},
			[RAID_MYTHIC] = {
				57087, 55883, 56747,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk
	[191009] = {
		Items = {
			[RAID_FINDER] = {
				56384, 56048, 56495, 
			},
			[RAID_NORMAL] = {
				56411, 57004, 56522, 
			},
			[RAID_HEROIC] = {
				56402, 56064, 56513, 
			},
			[RAID_MYTHIC] = {
				56393, 56088, 56504,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Chest
	-- Death Knight, Warlock, Demon Hunter
	[191010] = {
		Items = {
			[RAID_FINDER] = {
				56969, 55998, 56277, 
			},
			[RAID_NORMAL] = {
				56996, 56025, 56302, 
			},
			[RAID_HEROIC] = {
				56987, 56016, 56295, 
			},
			[RAID_MYTHIC] = {
				56978, 56007, 56286,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[191011] = {
		Items = {
			[RAID_FINDER] = {
				56331, 56636, 56171, 
			},
			[RAID_NORMAL] = {
				56358, 56666, 56201, 
			},
			[RAID_HEROIC] = {
				56349, 56656, 56191, 
			},
			[RAID_MYTHIC] = {
				56340, 56626, 56181,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[191012] = {
		Items = {
			[RAID_FINDER] = {
				57079, 55874, 56757, -- 55881 - alternate priest chest
			},
			[RAID_NORMAL] = {
				57106, 55904, 56730, -- 55911 - alternate priest chest
			},
			[RAID_HEROIC] = {
				57097, 55894, 56766, -- 55901 - alternate priest chest
			},
			[RAID_MYTHIC] = {
				57088, 55884, 56748, -- 55891 - alternate priest chest
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk
	[191013] = {
		Items = {
			[RAID_FINDER] = {
				56385, 56049, 56496, 
			},
			[RAID_NORMAL] = {
				56412, 56041, 56523, 
			},
			[RAID_HEROIC] = {
				56403, 56065, 56514, 
			},
			[RAID_MYTHIC] = {
				56394, 56089, 56505,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Hands
	-- Death Knight, Warlock, Demon Hunter
	[191014] = {
		Items = {
			[RAID_FINDER] = {
				56974, 56003, 56282, 
			},
			[RAID_NORMAL] = {
				57001, 56030, 56307, 
			},
			[RAID_HEROIC] = {
				56992, 56021, 56300, 
			},
			[RAID_MYTHIC] = {
				56983, 56012, 56291,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[191015] = {
		Items = {
			[RAID_FINDER] = {
				56336, 56641, 56176, 
			},
			[RAID_NORMAL] = {
				56363, 56671, 56206, 
			},
			[RAID_HEROIC] = {
				56354, 56661, 56196, 
			},
			[RAID_MYTHIC] = {
				56345, 56631, 56186,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[191016] = {
		Items = {
			[RAID_FINDER] = {
				57084, 55879, 56762, 
			},
			[RAID_NORMAL] = {
				57111, 55909, 56735, 
			},
			[RAID_HEROIC] = {
				57102, 55899, 56771, 
			},
			[RAID_MYTHIC] = {
				57093, 55889, 56753,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk
	[191017] = {
		Items = {
			[RAID_FINDER] = {
				56390, 56054, 56501, 
			},
			[RAID_NORMAL] = {
				56417, 56046, 56528, 
			},
			[RAID_HEROIC] = {
				56408, 56070, 56519, 
			},
			[RAID_MYTHIC] = {
				56399, 56094, 56510,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Legs
	-- Death Knight, Warlock, Demon Hunter
	[191018] = {
		Items = {
			[RAID_FINDER] = {
				56971, 56000, 56279,
			},
			[RAID_NORMAL] = {
				56998, 56027, 56304,
			},
			[RAID_HEROIC] = {
				56989, 56018, 56297,
			},
			[RAID_MYTHIC] = {
				56980, 56009, 56288,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[191019] = {
		Items = {
			[RAID_FINDER] = {
				56333, 56638, 56173, 
			},
			[RAID_NORMAL] = {
				56360, 56668, 56203, 
			},
			[RAID_HEROIC] = {
				56351, 56658, 56193, 
			},
			[RAID_MYTHIC] = {
				56342, 56628, 56183,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[191020] = {
		Items = {
			[RAID_FINDER] = {
				57081, 55876, 56759, 
			},
			[RAID_NORMAL] = {
				57108, 55906, 56732, 
			},
			[RAID_HEROIC] = {
				57099, 55896, 56768, 
			},
			[RAID_MYTHIC] = {
				57090, 55886, 56750,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk
	[191021] = {
		Items = {
			[RAID_FINDER] = {
				56387, 56051, 56498,
			},
			[RAID_NORMAL] = {
				56414, 56043, 56525,
			},
			[RAID_HEROIC] = {
				56405, 56067, 56516,
			},
			[RAID_MYTHIC] = {
				56091, 56396, 56525,
			},
		},
		Classes = CLASS_GROUP_4,
	},


	-- Nerub-ar Palace
	-- Helm
	-- Death Knight, Warlock, Demon Hunter
	[225622] = {
		Items = {
			[RAID_FINDER] = {
				91659, 93102, 91882,
			},
			[RAID_NORMAL] = {
				91650, 93037, 91831,
			},
			[RAID_HEROIC] = {
				91686, 93089, 91860,
			},
			[RAID_MYTHIC] = {
				91649, 93073, 91828,
			},
			[LegendaryCrafting_6] = {
				91650, 93037, 91831,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[225623] = {
		Items = {
			[RAID_FINDER] = {
				92495, 93013, 91592,
			},
			[RAID_NORMAL] = {
				92475, 92977, 91568,
			},
			[RAID_HEROIC] = {
				92525, 92989, 91580,
			},
			[RAID_MYTHIC] = {
				92513, 92974, 91565,
			},
			[LegendaryCrafting_6] = {
				92475, 92977, 91568,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[225624] = {
		Items = {
			[RAID_FINDER] = {
				92082, 92314, 92850,
			},
			[RAID_NORMAL] = {
				92027, 92270, 92802,
			},
			[RAID_HEROIC] = {
				92060, 92259, 92838,
			},
			[RAID_MYTHIC] = {
				92047, 92301, 92824,
			},
			[LegendaryCrafting_6] = {
				92027, 92270, 92802,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[225625] = {
		Items = {
			[RAID_FINDER] = {
				92427, 92772, 92191, 92129,
			},
			[RAID_NORMAL] = {
				92403, 92745, 92181, 92093,
			},
			[RAID_HEROIC] = {
				92463, 92754, 92211, 92117,
			},
			[RAID_MYTHIC] = {
				92448, 92781, 92179, 92162,
			},
			[LegendaryCrafting_6] = {
				92403, 92745, 92181, 92093,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Shoulder
	-- Death Knight, Warlock, Demon Hunter
	[225630] = {
		Items = {
			[RAID_FINDER] = {
				91513, 93103, 91883,
			},
			[RAID_NORMAL] = {
				91503, 93038, 91832,
			},
			[RAID_HEROIC] = {
				91543, 93090, 91861,
			},
			[RAID_MYTHIC] = {
				91501, 93074, 91829,
			},
			[LegendaryCrafting_6] = {
				91503, 93038, 91832,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[225631] = {
		Items = {
			[RAID_FINDER] = {
				92496, 93014, 91593,
			},
			[RAID_NORMAL] = {
				92476, 92978, 91569,
			},
			[RAID_HEROIC] = {
				92526, 92990, 91581,
			},
			[RAID_MYTHIC] = {
				92514, 92975, 91566,
			},
			[LegendaryCrafting_6] = {
				92476, 92978, 91569,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[225632] = {
		Items = {
			[RAID_FINDER] = {
				92083, 92554, 92851,
			},
			[RAID_NORMAL] = {
				92028, 92546, 92803,
			},
			[RAID_HEROIC] = {
				92061, 92544, 92839,
			},
			[RAID_MYTHIC] = {
				92048, 92551, 92825,
			},
			[LegendaryCrafting_6] = {
				92028, 92546, 92803,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[225633] = {
		Items = {
			[RAID_FINDER] = {
				92428, 92773, 92192, 92130,
			},
			[RAID_NORMAL] = {
				92404, 92746, 92182, 92094,
			},
			[RAID_HEROIC] = {
				92464, 92755, 92212, 92118,
			},
			[RAID_MYTHIC] = {
				92449, 92789, 92180, 92163,
			},
			[LegendaryCrafting_6] = {
				92404, 92746, 92182, 92094,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Chest
	-- Death Knight, Warlock, Demon Hunter
	[225614] = {
		Items = {
			[RAID_FINDER] = {
				91514, 93104, 91884,
			},
			[RAID_NORMAL] = {
				91504, 93039, 91833,
			},
			[RAID_HEROIC] = {
				91544, 93091, 91862,
			},
			[RAID_MYTHIC] = {
				91494, 93065, 91822,
			},
			[LegendaryCrafting_6] = {
				91504, 93039, 91833,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[225615] = {
		Items = {
			[RAID_FINDER] = {
				92497, 93015, 91594,
			},
			[RAID_NORMAL] = {
				92477, 92979, 91570,
			},
			[RAID_HEROIC] = {
				92527, 92991, 91582,
			},
			[RAID_MYTHIC] = {
				92507, 93126, 91558,
			},
			[LegendaryCrafting_6] = {
				92477, 92979, 91570,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[225616] = {
		Items = {
			[RAID_FINDER] = {
				92084, 92315, 92859,
			},
			[RAID_NORMAL] = {
				92029, 92271, 92811,
			},
			[RAID_HEROIC] = {
				92062, 92260, 92847,
			},
			[RAID_MYTHIC] = {
				92040, 92400, 92823,
			},
			[LegendaryCrafting_6] = {
				92029, 92271, 92811,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[225617] = {
		Items = {
			[RAID_FINDER] = {
				92429, 92774, 92193, 92131,
			},
			[RAID_NORMAL] = {
				92405, 92747, 92183, 92095,
			},
			[RAID_HEROIC] = {
				92465, 92756, 92213, 92119,
			},
			[RAID_MYTHIC] = {
				92441, 92783, 92173, 92155,
			},
			[LegendaryCrafting_6] = {
				92405, 92747, 92183, 92095,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Hands
	-- Death Knight, Warlock, Demon Hunter
	[225618] = {
		Items = {
			[RAID_FINDER] = {
				91519, 93109, 91889,
			},
			[RAID_NORMAL] = {
				91509, 93044, 91838,
			},
			[RAID_HEROIC] = {
				91549, 93096, 91867,
			},
			[RAID_MYTHIC] = {
				91499, 93070, 91972,
			},
			[LegendaryCrafting_6] = {
				91509, 93044, 91838,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[225619] = {
		Items = {
			[RAID_FINDER] = {
				92502, 93020, 91599,
			},
			[RAID_NORMAL] = {
				92482, 92984, 91575,
			},
			[RAID_HEROIC] = {
				92532, 92996, 91587,
			},
			[RAID_MYTHIC] = {
				92512, 93120, 91563,
			},
			[LegendaryCrafting_6] = {
				92482, 92984, 91575,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[225620] = {
		Items = {
			[RAID_FINDER] = {
				92089, 92320, 92857,
			},
			[RAID_NORMAL] = {
				92034, 92276, 92809,
			},
			[RAID_HEROIC] = {
				92067, 92265, 92845,
			},
			[RAID_MYTHIC] = {
				92045, 92327, 92821,
			},
			[LegendaryCrafting_6] = {
				92034, 92276, 92809,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[225621] = {
		Items = {
			[RAID_FINDER] = {
				92434, 92779, 92198, 92136,
			},
			[RAID_NORMAL] = {
				92410, 92752, 92188, 92100,
			},
			[RAID_HEROIC] = {
				92470, 92761, 92218, 92124,
			},
			[RAID_MYTHIC] = {
				92446, 92788, 92178, 92160,
			},
			[LegendaryCrafting_6] = {
				92410, 92752, 92188, 92100,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Legs
	-- Death Knight, Warlock, Demon Hunter
	[225626] = {
		Items = {
			[RAID_FINDER] = {
				91516, 93106, 91886,
			},
			[RAID_NORMAL] = {
				91506, 93041, 91835,
			},
			[RAID_HEROIC] = {
				91546, 93093, 91864,
			},
			[RAID_MYTHIC] = {
				91496, 93067, 91824,
			},
			[LegendaryCrafting_6] = {
				91506, 93041, 91835,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[225627] = {
		Items = {
			[RAID_FINDER] = {
				92499, 93017, 91596,
			},
			[RAID_NORMAL] = {
				92479, 92981, 91572,
			},
			[RAID_HEROIC] = {
				92529, 92993, 91584,
			},
			[RAID_MYTHIC] = {
				92509, 92969, 91560,
			},
			[LegendaryCrafting_6] = {
				92479, 92981, 91572,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[225628] = {
		Items = {
			[RAID_FINDER] = {
				92086, 92317, 94158,
			},
			[RAID_NORMAL] = {
				92031, 92273, 94162,
			},
			[RAID_HEROIC] = {
				92064, 92262, 94159,
			},
			[RAID_MYTHIC] = {
				92042, 92295, 94161,
			},
			[LegendaryCrafting_6] = {
				92031, 92273, 94162,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[225629] = {
		Items = {
			[RAID_FINDER] = {
				92431, 92776, 92195, 92133,
			},
			[RAID_NORMAL] = {
				92407, 92749, 92185, 92097,
			},
			[RAID_HEROIC] = {
				92467, 92758, 92215, 92121,
			},
			[RAID_MYTHIC] = {
				92443, 92785, 92175, 92157,
			},
			[LegendaryCrafting_6] = {
				92407, 92749, 92185, 92097,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Amirdrassil
	-- Helm
	-- Death Knight, Warlock, Demon Hunter
	[207470] = {
		Items = {
			[RAID_FINDER] = {
				82944, 81631, 81139,
			},
			[RAID_NORMAL] = {
				82955, 81619, 81148,
			},
			[RAID_HEROIC] = {
				82922, 81583, 81166,
			},
			[RAID_MYTHIC] = {
				82942, 81605, 81175,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[207471] = {
		Items = {
			[RAID_FINDER] = {
				82261, 81227, 82602, -- Hunter, Mage, Druid Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82291, 81260, 82613,
			},
			[RAID_HEROIC] = {
				82271, 81249, 82624,
			},
			[RAID_MYTHIC] = {
				82281, 81224, 82645,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[207472] = {
		Items = {
			[RAID_FINDER] = {
				81088, 82046, 81034, -- Paladin, Priest, Shaman Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				81077, 82094, 81045,
			},
			[RAID_HEROIC] = {
				81098, 82070, 81023,
			},
			[RAID_MYTHIC] = {
				81116, 82092, 81018,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[207473] = {
		Items = {
			[RAID_FINDER] = {
				82739, 82667, 81352, 82834, -- Warrior, Rogue, Monk, Evoker Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82757, 82703, 81392, 82823,
			},
			[RAID_HEROIC] = {
				82766, 82679, 81362, 82856,
			},
			[RAID_MYTHIC] = {
				82782, 82736, 81382, 82877,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Shoulder
	-- Death Knight, Warlock, Demon Hunter
	[207478] = {
		Items = {
			[RAID_FINDER] = {
				82998, 82668, 81353, 82835, -- Warrior, Rogue, Monk, Evoker Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				83002, 82704, 81393, 82824,
			},
			[RAID_HEROIC] = {
				83004, 82680, 81363, 82857,
			},
			[RAID_MYTHIC] = {
				83007, 82737, 81391, 82868,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[207479] = {
		Items = {
			[RAID_FINDER] = {
				82262, 81228, 82603, -- Hunter, Mage, Druid Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82292, 81261, 82614,
			},
			[RAID_HEROIC] = {
				82272, 81250, 82625,
			},
			[RAID_MYTHIC] = {
				82290, 81225, 82655,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[207480] = {
		Items = {
			[RAID_FINDER] = {
				81089, 82047, 81036, -- Paladin, Priest, Shaman Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				81069, 82095, 81043,
			},
			[RAID_HEROIC] = {
				81099, 82071, 81021,
			},
			[RAID_MYTHIC] = {
				81124, 82093, 81017,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[207481] = {
		Items = {
			[RAID_FINDER] = {
				82998, 82668, 81353, 82835, -- Warrior, Rogue, Monk, Evoker Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				83002, 82704, 81393, 82824,
			},
			[RAID_HEROIC] = {
				83004, 82680, 81363, 82857,
			},
			[RAID_MYTHIC] = {
				83007, 82737, 81391, 82868,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Chest
	-- Death Knight, Warlock, Demon Hunter
	[207462] = {
		Items = {
			[RAID_FINDER] = {
				82946, 81575, 81141,
			},
			[RAID_NORMAL] = {
				82957, 81621, 81150,
			},
			[RAID_HEROIC] = {
				82924, 81585, 81168,
			},
			[RAID_MYTHIC] = {
				82935, 81597, 81177,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[207463] = {
		Items = {
			[RAID_FINDER] = {
				82263, 81229, 82604, -- Hunter, Mage, Druid Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82293, 81262, 82615,
			},
			[RAID_HEROIC] = {
				82273, 81251, 82626,
			},
			[RAID_MYTHIC] = {
				82283, 81218, 82647,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[207464] = {	
		Items = {
			[RAID_FINDER] = {
				81090, 82055, 81032, -- Paladin, Priest, Shaman Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				81063, 82103, 81047,
			},
			[RAID_HEROIC] = {
				81100, 82079, 81026,
			},
			[RAID_MYTHIC] = {
				81118, 82091, 81016,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[207465] = {
		Items = {
			[RAID_FINDER] = {
				82740, 82669, 81354, 82843, -- Warrior, Rogue, Monk, Evoker Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82758, 82705, 81394, 82832,
			},
			[RAID_HEROIC] = {
				82767, 82681, 81364, 82865,
			},
			[RAID_MYTHIC] = {
				82797, 82729, 81384, 82876,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Hands
	-- Death Knight, Warlock, Demon Hunter
	[207466] = {
		Items = {
			[RAID_FINDER] = {
				82951, 81580, 81146,
			},
			[RAID_NORMAL] = {
				82962, 81626, 81155,
			},
			[RAID_HEROIC] = {
				82929, 81590, 81173,
			},
			[RAID_MYTHIC] = {
				82940, 81602, 81182,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[207467] = {
		Items = {
			[RAID_FINDER] = {
				82268, 81234, 82609, -- Hunter, Mage, Druid Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82298, 81267, 82620,
			},
			[RAID_HEROIC] = {
				82278, 81256, 82631,
			},
			[RAID_MYTHIC] = {
				82288, 81223, 82652,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[207468] = {
		Items = {
			[RAID_FINDER] = {
				81095, 82053, 81031, -- Paladin, Priest, Shaman Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				81064, 82101, 81048,
			},
			[RAID_HEROIC] = {
				81105, 82077, 81027,
			},
			[RAID_MYTHIC] = {
				81123, 82089, 81010,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[207469] = {
		Items = {
			[RAID_FINDER] = {
				82745, 82674, 81359, 82841, -- Warrior, Rogue, Monk, Evoker Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82763, 82710, 81399, 82830,
			},
			[RAID_HEROIC] = {
				82772, 82686, 81369, 82863,
			},
			[RAID_MYTHIC] = {
				82781, 82734, 81389, 82874,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Legs
	-- Death Knight, Warlock, Demon Hunter
	[207474] = {
		Items = {
			[RAID_FINDER] = {
				82948, 81577, 81143,
			},
			[RAID_NORMAL] = {
				82959, 81623, 81152,
			},
			[RAID_HEROIC] = {
				82926, 81587, 81170,
			},
			[RAID_MYTHIC] = {
				82937, 81599, 81179,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	-- Hunter, Mage, Druid
	[207475] = {
		Items = {
			[RAID_FINDER] = {
				82265, 81231, 82606, -- Hunter, Mage, Druid Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82295, 81264, 82617,
			},
			[RAID_HEROIC] = {
				82275, 81253, 82628,
			},
			[RAID_MYTHIC] = {
				82285, 81220, 82649,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	-- Paladin, Priest, Shaman
	[207476] = {
		Items = {
			[RAID_FINDER] = {
				81092, 82050, 81035, -- Paladin, Priest, Shaman Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				81067, 82098, 81044,
			},
			[RAID_HEROIC] = {
				81102, 82074, 81022,
			},
			[RAID_MYTHIC] = {
				81120, 82086, 81008,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	-- Warrior, Rogue, Monk, Evoker
	[207477] = {
		Items = {
			[RAID_FINDER] = {
				82742, 82671, 81356, 82838, -- Warrior, Rogue, Monk, Evoker Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				82760, 82707, 81396, 82827,
			},
			[RAID_HEROIC] = {
				82769, 82683, 81366, 82860,
			},
			[RAID_MYTHIC] = {
				82778, 82731, 81386, 82871,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	--Aberrus
	-- Death Knight, Warlock, Demon Hunter
	[202627] = {
		Items = {
			[RAID_FINDER] = {
				80411, 79580, 80547, -- Death Knight, Warlock, Demon Hunter Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80400, 79593, 80536,
			},
			[RAID_HEROIC] = {
				80444, 79567, 80580,
			},
			[RAID_MYTHIC] = {
				80442, 79564, 80578,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[202621] = {
		Items = {
			[RAID_FINDER] = {
				80412, 79581, 80548, -- Death Knight, Warlock, Demon Hunter Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80401, 79594, 80537,
			},
			[RAID_HEROIC] = {
				80445, 79568, 80581,
			},
			[RAID_MYTHIC] = {
				80443, 79565, 80579,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[202631] = {
		Items = {
			[RAID_FINDER] = {
				80413, 79582, 80549, -- Death Knight, Warlock, Demon Hunter Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80402, 79595, 80538,
			},
			[RAID_HEROIC] = {
				80446, 79569, 80582,
			},
			[RAID_MYTHIC] = {
				80435, 79556, 80571,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[202624] = {
		Items = {
			[RAID_FINDER] = {
				80418, 79587, 80554, -- Death Knight, Warlock, Demon Hunter Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80407, 79600, 80543,
			},
			[RAID_HEROIC] = {
				80451, 79574, 80587,
			},
			[RAID_MYTHIC] = {
				80440, 79561, 80576,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[202634] = {
		Items = {
			[RAID_FINDER] = {
				80415, 79584, 80551, -- Death Knight, Warlock, Demon Hunter Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80404, 79597, 80540,
			},
			[RAID_HEROIC] = {
				80448, 79571, 80584,
			},
			[RAID_MYTHIC] = {
				80437, 79558, 80573,
			},
		},
		Classes = CLASS_GROUP_1,
	},

	-- Hunter, Mage, Druid
	[202628] = {
		Items = {
			[RAID_FINDER] = {
				79925, 80496, 78936, -- Hunter, Mage, Druid Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79903, 80515, 78876,
			},
			[RAID_HEROIC] = {
				79958, 80466, 78924,
			},
			[RAID_MYTHIC] = {
				79956, 80811, 78921,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[202622] = {
		Items = {
			[RAID_FINDER] = {
				79926, 80497, 78937, -- Hunter, Mage, Druid Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79904, 80516, 78877,
			},
			[RAID_HEROIC] = {
				79959, 80467, 78925,
			},
			[RAID_MYTHIC] = {
				79957, 80513, 78922,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[202632] = {
		Items = {
			[RAID_FINDER] = {
				79927, 80498, 78938, -- Hunter, Mage, Druid Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79905, 80517, 78878,
			},
			[RAID_HEROIC] = {
				79960, 80468, 78926,
			},
			[RAID_MYTHIC] = {
				79949, 80507, 78914,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[202625] = {
		Items = {
			[RAID_FINDER] = {
				79932, 80503, 78943, -- Hunter, Mage, Druid Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79910, 80522, 78883,
			},
			[RAID_HEROIC] = {
				79965, 80473, 78931,
			},
			[RAID_MYTHIC] = {
				79954, 80512, 78919,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[202635] = {
		Items = {
			[RAID_FINDER] = {
				79929, 80500, 78940, -- Hunter, Mage, Druid Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79907, 80519, 78880,
			},
			[RAID_HEROIC] = {
				79962, 80470, 78928,
			},
			[RAID_MYTHIC] = {
				79951, 80509, 78916,
			},
		},
		Classes = CLASS_GROUP_2,
	},

	-- Paladin, Priest, Shaman
	[202629] = {
		Items = {
			[RAID_FINDER] = {
				79067, 79196, 78972, -- Paladin, Priest, Shaman Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79089, 79246, 79008,
			},
			[RAID_HEROIC] = {
				79078, 79216, 78996,
			},
			[RAID_MYTHIC] = {
				79065, 79215, 78993,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[202623] = {
		Items = {
			[RAID_FINDER] = {
				79068, 79197, 78973, -- Paladin, Priest, Shaman Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79090, 79247, 79009,
			},
			[RAID_HEROIC] = {
				79079, 79217, 78997,
			},
			[RAID_MYTHIC] = {
				79066, 79207, 78994,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[202633] = {
		Items = {
			[RAID_FINDER] = {
				79075, 79198, 78974, -- Paladin, Priest, Shaman Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79097, 79248, 79010,
			},
			[RAID_HEROIC] = {
				79086, 79218, 78998,
			},
			[RAID_MYTHIC] = {
				79064, 79208, 78986,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[202626] = {
		Items = {
			[RAID_FINDER] = {
				79074, 79203, 78979, -- Paladin, Priest, Shaman Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79096, 79253, 79015,
			},
			[RAID_HEROIC] = {
				79085, 79223, 79003,
			},
			[RAID_MYTHIC] = {
				79063, 79213, 78991,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[202636] = {
		Items = {
			[RAID_FINDER] = {
				79071, 79200, 78976, -- Paladin, Priest, Shaman Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				79093, 79250, 79012,
			},
			[RAID_HEROIC] = {
				79082, 79220, 79000,
			},
			[RAID_MYTHIC] = {
				79060, 79210, 78988,
			},
		},
		Classes = CLASS_GROUP_3,
	},

	-- Warrior, Rogue, Monk, Evoker
	[202630] = {
		Items = {
			[RAID_FINDER] = {
				80709, 78388, 79656, 80615, -- Warrior, Rogue, Monk, Evoker Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80661, 78398, 79606, 80591,
			},
			[RAID_HEROIC] = {
				80673, 78378, 79646, 80649,
			},
			[RAID_MYTHIC] = {
				80730, 78368, 79644, 80647,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[202637] = {
		Items = {
			[RAID_FINDER] = {
				80710, 78389, 79657, 80616, -- Warrior, Rogue, Monk, Evoker Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80662, 78399, 79607, 80592,
			},
			[RAID_HEROIC] = {
				80674, 78379, 79647, 80650,
			},
			[RAID_MYTHIC] = {
				80731, 78377, 79645, 80813,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[202639] = {
		Items = {
			[RAID_FINDER] = {
				80711, 78390, 79658, 80617, -- Warrior, Rogue, Monk, Evoker Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80663, 78400, 79608, 80593,
			},
			[RAID_HEROIC] = {
				80675, 78380, 79648, 80651,
			},
			[RAID_MYTHIC] = {
				80723, 78370, 79638, 80640,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[202638] = {
		Items = {
			[RAID_FINDER] = {
				80716, 78395, 79663, 80622, -- Warrior, Rogue, Monk, Evoker Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80668, 78405, 79613, 80598,
			},
			[RAID_HEROIC] = {
				80680, 78385, 79653, 80656,
			},
			[RAID_MYTHIC] = {
				80728, 78375, 79643, 80645,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[202640] = {
		Items = {
			[RAID_FINDER] = {
				80713, 78392, 79660, 80619, -- Warrior, Rogue, Monk, Evoker Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				80665, 78402, 79610, 80595,
			},
			[RAID_HEROIC] = {
				80677, 78382, 79650, 80653,
			},
			[RAID_MYTHIC] = {
				80725, 78372, 79640, 80642,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Vault of the Incarnates
	[196590] = {
		Items = {
			[RAID_FINDER] = {
				76262, 75562, 75938, -- Death Knight, Warlock, Demon Hunter Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76229, 75536, 75918,
			},
			[RAID_HEROIC] = {
				76251, 75575, 75948,
			},
			[RAID_MYTHIC] = {
				76227, 75533, 75916,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[196589] = {
		Items = {
			[RAID_FINDER] = {
				76263, 75563, 75939, -- Death Knight, Warlock, Demon Hunter Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76230, 75537, 75919,
			},
			[RAID_HEROIC] = {
				76252, 75576, 75949,
			},
			[RAID_MYTHIC] = {
				76228, 75534, 75917,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[196586] = {
		Items = {
			[RAID_FINDER] = {
				76264, 75564, 75940, -- Death Knight, Warlock, Demon Hunter Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76231, 75538, 75920,
			},
			[RAID_HEROIC] = {
				76253, 75577, 75950,
			},
			[RAID_MYTHIC] = {
				76220, 75525, 75910,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[196587] = {
		Items = {
			[RAID_FINDER] = {
				76269, 75569, 75945, -- Death Knight, Warlock, Demon Hunter Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76236, 75543, 75925,
			},
			[RAID_HEROIC] = {
				76258, 75582, 75955,
			},
			[RAID_MYTHIC] = {
				76225, 75530, 75915,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[196588] = {
		Items = {
			[RAID_FINDER] = {
				76266, 75566, 75942, -- Death Knight, Warlock, Demon Hunter Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76233, 75540, 75922,
			},
			[RAID_HEROIC] = {
				76255, 75579, 75952,
			},
			[RAID_MYTHIC] = {
				76222, 75527, 75912,
			},
		},
		Classes = CLASS_GROUP_1,
	},

	[196600] = {
		Items = {
			[RAID_FINDER] = {
				76196, 75631, 76139, -- Hunter, Mage, Druid Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76174, 75609, 76115,
			},
			[RAID_HEROIC] = {
				76207, 75642, 76151,
			},
			[RAID_MYTHIC] = {
				76172, 75607, 76113,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[196599] = {
		Items = {
			[RAID_FINDER] = {
				76197, 75632, 76140, -- Hunter, Mage, Druid Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76175, 75610, 76116,
			},
			[RAID_HEROIC] = {
				76208, 75643, 76152,
			},
			[RAID_MYTHIC] = {
				76173, 75608, 76114,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[196596] = {
		Items = {
			[RAID_FINDER] = {
				76198, 75633, 76141, -- Hunter, Mage, Druid Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76176, 75611, 76117,
			},
			[RAID_HEROIC] = {
				76209, 75644, 76153,
			},
			[RAID_MYTHIC] = {
				76165, 75600, 76105,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[196597] = {
		Items = {
			[RAID_FINDER] = {
				76203, 75638, 76146, -- Hunter, Mage, Druid Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76181, 75616, 76122,
			},
			[RAID_HEROIC] = {
				76214, 75649, 76158,
			},
			[RAID_MYTHIC] = {
				76170, 75605, 76283,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[196598] = {
		Items = {
			[RAID_FINDER] = {
				76200, 75635, 76143, -- Hunter, Mage, Druid Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76178, 75613, 76119,
			},
			[RAID_HEROIC] = {
				76211, 75646, 76155,
			},
			[RAID_MYTHIC] = {
				76167, 75602, 76107,
			},
		},
		Classes = CLASS_GROUP_2,
	},

	[196605] = {
		Items = {
			[RAID_FINDER] = {
				76046, 75369, 76430, -- Paladin, Priest, Shaman Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76024, 75345, 76408,
			},
			[RAID_HEROIC] = {
				76057, 75381, 76441,
			},
			[RAID_MYTHIC] = {
				76013, 75343, 76406,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[196604] = {
		Items = {
			[RAID_FINDER] = {
				76047, 75370, 76431, -- Paladin, Priest, Shaman Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76025, 75346, 76409,
			},
			[RAID_HEROIC] = {
				76058, 75382, 76442,
			},
			[RAID_MYTHIC] = {
				76023, 75344, 76407,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[196601] = {
		Items = {
			[RAID_FINDER] = {
				76048, 75371, 76432, -- Paladin, Priest, Shaman Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76026, 75347, 76410,
			},
			[RAID_HEROIC] = {
				76059, 75383, 76449,
			},
			[RAID_MYTHIC] = {
				76278, 75335, 76399,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[196602] = {
		Items = {
			[RAID_FINDER] = {
				76053, 75376, 76437, -- Paladin, Priest, Shaman Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76031, 75352, 76415,
			},
			[RAID_HEROIC] = {
				76064, 75388, 76448,
			},
			[RAID_MYTHIC] = {
				76020, 75340, 76404,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[196603] = {
		Items = {
			[RAID_FINDER] = {
				76050, 75373, 76434, -- Paladin, Priest, Shaman Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76028, 75349, 76412,
			},
			[RAID_HEROIC] = {
				76061, 75385, 76445,
			},
			[RAID_MYTHIC] = {
				76017, 75337, 76401,
			},
		},
		Classes = CLASS_GROUP_3,
	},

	[196595] = {
		Items = {
			[RAID_FINDER] = {
				76490, 78048, 75743, 76886, -- Warrior, Rogue, Monk, Evoker Head Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76468, 78015, 75723, 76864,
			},
			[RAID_HEROIC] = {
				76501, 78059, 75753, 76897,
			},
			[RAID_MYTHIC] = {
				76466, 78070, 75713, 76862,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[196594] = {
		Items = {
			[RAID_FINDER] = {
				76491, 78049, 75744, 76887, -- Warrior, Rogue, Monk, Evoker Shoulder Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76469, 78016, 75724, 76865,
			},
			[RAID_HEROIC] = {
				76502, 78060, 75754, 76898,
			},
			[RAID_MYTHIC] = {
				76467, 78014, 75722, 76863,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[196591] = {
		Items = {
			[RAID_FINDER] = {
				76492, 78050, 75745, 76888, -- Warrior, Rogue, Monk, Evoker Chest Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76470, 78017, 75725, 76866,
			},
			[RAID_HEROIC] = {
				76503, 78061, 75755, 76899,
			},
			[RAID_MYTHIC] = {
				76459, 78007, 75715, 76855,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[196592] = {
		Items = {
			[RAID_FINDER] = {
				76497, 78055, 75750, 76893, -- Warrior, Rogue, Monk, Evoker Hand Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76475, 78022, 75730, 76871,
			},
			[RAID_HEROIC] = {
				76508, 78066, 75760, 76904,
			},
			[RAID_MYTHIC] = {
				76464, 78012, 75720, 76860,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[196593] = {
		Items = {
			[RAID_FINDER] = {
				76494, 78052, 75747, 76890, -- Warrior, Rogue, Monk, Evoker Leg Slot IDs grouped together
			},
			[RAID_NORMAL] = {
				76472, 78019, 75727, 76868,
			},
			[RAID_HEROIC] = {
				76505, 78063, 75757, 76901,
			},
			[RAID_MYTHIC] = {
				76461, 78009, 75717, 76857,
			},
		},
		Classes = CLASS_GROUP_4,
	},


	-- Siege of Orgrimmar (Raid Finder)
	[99672] = {
		Items = {
			[RAID_FINDER] = {
				20889, 20910, 20925, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL] = {
				20964, 21060, 20947,
			},
			[RAID_HEROIC] = {
				21028, 21023, 21053,
			},
			[RAID_MYTHIC] = {
				21028, 21023, 21053,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99669] = {
		Items = {
			[RAID_FINDER] = {
				20895, 20903, 20919, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20961, 21059, 20996,
			},
			[RAID_HEROIC] = {
				21025, 21021, 21051,
			},
			[RAID_MYTHIC] = {
				21025, 21021, 21051,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99678] = {
		Items = {
			[RAID_FINDER] = {
				20901, 20902, 20927, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20962, 20950, 20995,
			},
			[RAID_HEROIC] = {
				21026, 21020, 21050,
			},
			[RAID_MYTHIC] = {
				21026, 21020, 21050,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99681] = {
		Items = {
			[RAID_FINDER] = {
				20892, 20909, 20924, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20963, 20959, 20946,
			},
			[RAID_HEROIC] = {
				21027, 21022, 21052,
			},
			[RAID_MYTHIC] = {
				21027, 21022, 21052,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99675] = {
		Items = {
			[RAID_FINDER] = {
				20890, 20911, 20926, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20960, 20958, 20948,
			},
			[RAID_HEROIC] = {
				21029, 21024, 21054,
			},
			[RAID_MYTHIC] = {
				21029, 21024, 21054,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[99673] = {
		Items = {
			[RAID_FINDER] = {
				20913, 20935, 20893, 20931, -- Warrior, Hunter, Shaman, Monk Head Slot IDs
			},
			[RAID_NORMAL] = {
				20994, 20972, 20943, 20967,
			},
			[RAID_HEROIC] = {
				21047, 21040, 21010, 21033,
			},
			[RAID_MYTHIC] = {
				21047, 21040, 21010, 21033,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99670] = {
		Items = {
			[RAID_FINDER] = {
				20912, 20937, 21494, 20923, -- Warrior, Hunter, Shaman, Monk Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20991, 20974, 21484, 20969,
			},
			[RAID_HEROIC] = {
				21045, 21042, 21489, 21030,
			},
			[RAID_MYTHIC] = {
				21045, 21042, 21489, 21030,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99679] = {
		Items = {
			[RAID_FINDER] = {
				20916, 20940, 21493, 20929, -- Warrior, Hunter, Shaman, Monk Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20992, 20982, 21483, 20965,
			},
			[RAID_HEROIC] = {
				21049, 21043, 21488, 21031,
			},
			[RAID_MYTHIC] = {
				21049, 21043, 21488, 21031,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99667] = {
		Items = {
			[RAID_FINDER] = {
				20915, 20941, 20896, 20930, -- Warrior, Hunter, Shaman, Monk Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20993, 20983, 20942, 20966,
			},
			[RAID_HEROIC] = {
				21046, 21044, 21013, 21032,
			},
			[RAID_MYTHIC] = {
				21046, 21044, 21013, 21032,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99676] = {
		Items = {
			[RAID_FINDER] = {
				20914, 20936, 20894, 20922, -- Warrior, Hunter, Shaman, Monk Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20990, 20973, 20944, 20968,
			},
			[RAID_HEROIC] = {
				21048, 21041, 21558, 21561,
			},
			[RAID_MYTHIC] = {
				21048, 21041, 21558, 21561,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[99671] = {
		Items = {
			[RAID_FINDER] = {
				20906, 20921, 20939, 20899, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL] = {
				21061, 21058, 20976, 20979,
			},
			[RAID_HEROIC] = {
				21015, 21001, 21036, 21006,
			},
			[RAID_MYTHIC] = {
				21015, 21001, 21036, 21006,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99668] = {
		Items = {
			[RAID_FINDER] = {
				20908, 20918, 20934, 20888, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				21062, 21063, 20971, 20981,
			},
			[RAID_HEROIC] = {
				21017, 21003, 21039, 21000,
			},
			[RAID_MYTHIC] = {
				21017, 21003, 21039, 21000,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99677] = {
		Items = {
			[RAID_FINDER] = {
				20904, 20928, 21567, 20900, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20952, 20987, 21502, 20984,
			},
			[RAID_HEROIC] = {
				21019, 21008, 21557, 21004,
			},
			[RAID_MYTHIC] = {
				21019, 21008, 21557, 21004,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99680] = {
		Items = {
			[RAID_FINDER] = {
				20905, 20920, 20938, 20898, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20953, 20988, 20975, 20978,
			},
			[RAID_HEROIC] = {
				21018, 21009, 21035, 21005,
			},
			[RAID_MYTHIC] = {
				21018, 21009, 21035, 21005,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99674] = {
		Items = {
			[RAID_FINDER] = {
				20907, 20917, 20932, 20891, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20955, 20986, 20977, 20980,
			},
			[RAID_HEROIC] = {
				21016, 21002, 21037, 21007,
			},
			[RAID_MYTHIC] = {
				21016, 21002, 21037, 21007,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Siege of Orgrimmar (Normal)
	[99749] = {
		Items = {
			[RAID_FINDER] = {
				20889, 20910, 20925, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL] = {
				20964, 21060, 20947,
			},
			[RAID_HEROIC] = {
				21028, 21023, 21053,
			},
			[RAID_MYTHIC] = {
				21028, 21023, 21053,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99755] = {
		Items = {
			[RAID_FINDER] = {
				20895, 20903, 20919, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20961, 21059, 20996,
			},
			[RAID_HEROIC] = {
				21025, 21021, 21051,
			},
			[RAID_MYTHIC] = {
				21025, 21021, 21051,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99743] = {
		Items = {
			[RAID_FINDER] = {
				20901, 20902, 20927, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20962, 20950, 20995,
			},
			[RAID_HEROIC] = {
				21026, 21020, 21050,
			},
			[RAID_MYTHIC] = {
				21026, 21020, 21050,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99746] = {
		Items = {
			[RAID_FINDER] = {
				20892, 20909, 20924, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20963, 20959, 20946,
			},
			[RAID_HEROIC] = {
				21027, 21022, 21052,
			},
			[RAID_MYTHIC] = {
				21027, 21022, 21052,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99752] = {
		Items = {
			[RAID_FINDER] = {
				20890, 20911, 20926, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20960, 20958, 20948,
			},
			[RAID_HEROIC] = {
				21029, 21024, 21054,
			},
			[RAID_MYTHIC] = {
				21029, 21024, 21054,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[99750] = {
		Items = {
			[RAID_FINDER] = {
				20913, 20935, 20893, 20931, -- Warrior, Hunter, Shaman, Monk Head Slot IDs
			},
			[RAID_NORMAL] = {
				20994, 20972, 20943, 20967,
			},
			[RAID_HEROIC] = {
				21047, 21040, 21010, 21033,
			},
			[RAID_MYTHIC] = {
				21047, 21040, 21010, 21033,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99756] = {
		Items = {
			[RAID_FINDER] = {
				20912, 20937, 21494, 20923, -- Warrior, Hunter, Shaman, Monk Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20991, 20974, 21484, 20969,
			},
			[RAID_HEROIC] = {
				21045, 21042, 21489, 21030,
			},
			[RAID_MYTHIC] = {
				21045, 21042, 21489, 21030,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99744] = {
		Items = {
			[RAID_FINDER] = {
				20916, 20940, 21493, 20929, -- Warrior, Hunter, Shaman, Monk Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20992, 20982, 21483, 20965,
			},
			[RAID_HEROIC] = {
				21049, 21043, 21488, 21031,
			},
			[RAID_MYTHIC] = {
				21049, 21043, 21488, 21031,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99747] = {
		Items = {
			[RAID_FINDER] = {
				20915, 20941, 20896, 20930, -- Warrior, Hunter, Shaman, Monk Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20993, 20983, 20942, 20966,
			},
			[RAID_HEROIC] = {
				21046, 21044, 21013, 21032,
			},
			[RAID_MYTHIC] = {
				21046, 21044, 21013, 21032,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99753] = {
		Items = {
			[RAID_FINDER] = {
				20914, 20936, 20894, 20922, -- Warrior, Hunter, Shaman, Monk Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20990, 20973, 20944, 20968,
			},
			[RAID_HEROIC] = {
				21048, 21041, 21558, 21561,
			},
			[RAID_MYTHIC] = {
				21048, 21041, 21558, 21561,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[99748] = {
		Items = {
			[RAID_FINDER] = {
				20906, 20921, 20939, 20899, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL] = {
				21061, 21058, 20976, 20979,
			},
			[RAID_HEROIC] = {
				21015, 21001, 21036, 21006,
			},
			[RAID_MYTHIC] = {
				21015, 21001, 21036, 21006,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99754] = {
		Items = {
			[RAID_FINDER] = {
				20908, 20918, 20934, 20888, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				21062, 21063, 20971, 20981,
			},
			[RAID_HEROIC] = {
				21017, 21003, 21039, 21000,
			},
			[RAID_MYTHIC] = {
				21017, 21003, 21039, 21000,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99742] = {
		Items = {
			[RAID_FINDER] = {
				20904, 20928, 21567, 20900, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20952, 20987, 21502, 20984,
			},
			[RAID_HEROIC] = {
				21019, 21008, 21557, 21004,
			},
			[RAID_MYTHIC] = {
				21019, 21008, 21557, 21004,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99745] = {
		Items = {
			[RAID_FINDER] = {
				20905, 20920, 20938, 20898, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20953, 20988, 20975, 20978,
			},
			[RAID_HEROIC] = {
				21018, 21009, 21035, 21005,
			},
			[RAID_MYTHIC] = {
				21018, 21009, 21035, 21005,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99751] = {
		Items = {
			[RAID_FINDER] = {
				20907, 20917, 20932, 20891, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20955, 20986, 20977, 20980,
			},
			[RAID_HEROIC] = {
				21016, 21002, 21037, 21007,
			},
			[RAID_MYTHIC] = {
				21016, 21002, 21037, 21007,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Siege of Orgrimmar (Heroic)
	[99689] = {
		Items = {
			[RAID_FINDER] = {
				20889, 20910, 20925, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL] = {
				20964, 21060, 20947,
			},
			[RAID_HEROIC] = {
				21028, 21023, 21053,
			},
			[RAID_MYTHIC] = {
				21028, 21023, 21053,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99690] = {
		Items = {
			[RAID_FINDER] = {
				20895, 20903, 20919, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20961, 21059, 20996,
			},
			[RAID_HEROIC] = {
				21025, 21021, 21051,
			},
			[RAID_MYTHIC] = {
				21025, 21021, 21051,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99686] = {
		Items = {
			[RAID_FINDER] = {
				20901, 20902, 20927, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20962, 20950, 20995,
			},
			[RAID_HEROIC] = {
				21026, 21020, 21050,
			},
			[RAID_MYTHIC] = {
				21026, 21020, 21050,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99687] = {
		Items = {
			[RAID_FINDER] = {
				20892, 20909, 20924, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20963, 20959, 20946,
			},
			[RAID_HEROIC] = {
				21027, 21022, 21052,
			},
			[RAID_MYTHIC] = {
				21027, 21022, 21052,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99688] = {
		Items = {
			[RAID_FINDER] = {
				20890, 20911, 20926, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20960, 20958, 20948,
			},
			[RAID_HEROIC] = {
				21029, 21024, 21054,
			},
			[RAID_MYTHIC] = {
				21029, 21024, 21054,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[99694] = {
		Items = {
			[RAID_FINDER] = {
				20913, 20935, 20893, 20931, -- Warrior, Hunter, Shaman, Monk Head Slot IDs
			},
			[RAID_NORMAL] = {
				20994, 20972, 20943, 20967,
			},
			[RAID_HEROIC] = {
				21047, 21040, 21010, 21033,
			},
			[RAID_MYTHIC] = {
				21047, 21040, 21010, 21033,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99695] = {
		Items = {
			[RAID_FINDER] = {
				20912, 20937, 21494, 20923, -- Warrior, Hunter, Shaman, Monk Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20991, 20974, 21484, 20969,
			},
			[RAID_HEROIC] = {
				21045, 21042, 21489, 21030,
			},
			[RAID_MYTHIC] = {
				21045, 21042, 21489, 21030,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99691] = {
		Items = {
			[RAID_FINDER] = {
				20916, 20940, 21493, 20929, -- Warrior, Hunter, Shaman, Monk Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20992, 20982, 21483, 20965,
			},
			[RAID_HEROIC] = {
				21049, 21043, 21488, 21031,
			},
			[RAID_MYTHIC] = {
				21049, 21043, 21488, 21031,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99692] = {
		Items = {
			[RAID_FINDER] = {
				20915, 20941, 20896, 20930, -- Warrior, Hunter, Shaman, Monk Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20993, 20983, 20942, 20966,
			},
			[RAID_HEROIC] = {
				21046, 21044, 21013, 21032,
			},
			[RAID_MYTHIC] = {
				21046, 21044, 21013, 21032,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99693] = {
		Items = {
			[RAID_FINDER] = {
				20914, 20936, 20894, 20922, -- Warrior, Hunter, Shaman, Monk Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20990, 20973, 20944, 20968,
			},
			[RAID_HEROIC] = {
				21048, 21041, 21558, 21561,
			},
			[RAID_MYTHIC] = {
				21048, 21041, 21558, 21561,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[99683] = {
		Items = {
			[RAID_FINDER] = {
				20906, 20921, 20939, 20899, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL] = {
				21061, 21058, 20976, 20979,
			},
			[RAID_HEROIC] = {
				21015, 21001, 21036, 21006,
			},
			[RAID_MYTHIC] = {
				21015, 21001, 21036, 21006,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99685] = {
		Items = {
			[RAID_FINDER] = {
				20908, 20918, 20934, 20888, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				21062, 21063, 20971, 20981,
			},
			[RAID_HEROIC] = {
				21017, 21003, 21039, 21000,
			},
			[RAID_MYTHIC] = {
				21017, 21003, 21039, 21000,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99696] = {
		Items = {
			[RAID_FINDER] = {
				20904, 20928, 21567, 20900, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20952, 20987, 21502, 20984,
			},
			[RAID_HEROIC] = {
				21019, 21008, 21557, 21004,
			},
			[RAID_MYTHIC] = {
				21019, 21008, 21557, 21004,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99682] = {
		Items = {
			[RAID_FINDER] = {
				20905, 20920, 20938, 20898, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20953, 20988, 20975, 20978,
			},
			[RAID_HEROIC] = {
				21018, 21009, 21035, 21005,
			},
			[RAID_MYTHIC] = {
				21018, 21009, 21035, 21005,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99684] = {
		Items = {
			[RAID_FINDER] = {
				20907, 20917, 20932, 20891, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20955, 20986, 20977, 20980,
			},
			[RAID_HEROIC] = {
				21016, 21002, 21037, 21007,
			},
			[RAID_MYTHIC] = {
				21016, 21002, 21037, 21007,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Siege of Orgrimmar (Mythic)
	[99724] = {
		Items = {
			[RAID_FINDER] = {
				20889, 20910, 20925, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL] = {
				20964, 21060, 20947,
			},
			[RAID_HEROIC] = {
				21028, 21023, 21053,
			},
			[RAID_MYTHIC] = {
				21028, 21023, 21053,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99718] = {
		Items = {
			[RAID_FINDER] = {
				20895, 20903, 20919, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20961, 21059, 20996,
			},
			[RAID_HEROIC] = {
				21025, 21021, 21051,
			},
			[RAID_MYTHIC] = {
				21025, 21021, 21051,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99715] = {
		Items = {
			[RAID_FINDER] = {
				20901, 20902, 20927, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20962, 20950, 20995,
			},
			[RAID_HEROIC] = {
				21026, 21020, 21050,
			},
			[RAID_MYTHIC] = {
				21026, 21020, 21050,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99721] = {
		Items = {
			[RAID_FINDER] = {
				20892, 20909, 20924, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20963, 20959, 20946,
			},
			[RAID_HEROIC] = {
				21027, 21022, 21052,
			},
			[RAID_MYTHIC] = {
				21027, 21022, 21052,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[99712] = {
		Items = {
			[RAID_FINDER] = {
				20890, 20911, 20926, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20960, 20958, 20948,
			},
			[RAID_HEROIC] = {
				21029, 21024, 21054,
			},
			[RAID_MYTHIC] = {
				21029, 21024, 21054,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[99725] = {
		Items = {
			[RAID_FINDER] = {
				20913, 20935, 20893, 20931, -- Warrior, Hunter, Shaman, Monk Head Slot IDs
			},
			[RAID_NORMAL] = {
				20994, 20972, 20943, 20967,
			},
			[RAID_HEROIC] = {
				21047, 21040, 21010, 21033,
			},
			[RAID_MYTHIC] = {
				21047, 21040, 21010, 21033,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99719] = {
		Items = {
			[RAID_FINDER] = {
				20912, 20937, 21494, 20923, -- Warrior, Hunter, Shaman, Monk Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				20991, 20974, 21484, 20969,
			},
			[RAID_HEROIC] = {
				21045, 21042, 21489, 21030,
			},
			[RAID_MYTHIC] = {
				21045, 21042, 21489, 21030,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99716] = {
		Items = {
			[RAID_FINDER] = {
				20916, 20940, 21493, 20929, -- Warrior, Hunter, Shaman, Monk Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20992, 20982, 21483, 20965,
			},
			[RAID_HEROIC] = {
				21049, 21043, 21488, 21031,
			},
			[RAID_MYTHIC] = {
				21049, 21043, 21488, 21031,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99722] = {
		Items = {
			[RAID_FINDER] = {
				20915, 20941, 20896, 20930, -- Warrior, Hunter, Shaman, Monk Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20993, 20983, 20942, 20966,
			},
			[RAID_HEROIC] = {
				21046, 21044, 21013, 21032,
			},
			[RAID_MYTHIC] = {
				21046, 21044, 21013, 21032,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[99713] = {
		Items = {
			[RAID_FINDER] = {
				20914, 20936, 20894, 20922, -- Warrior, Hunter, Shaman, Monk Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20990, 20973, 20944, 20968,
			},
			[RAID_HEROIC] = {
				21048, 21041, 21558, 21561,
			},
			[RAID_MYTHIC] = {
				21048, 21041, 21558, 21561,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[99723] = {
		Items = {
			[RAID_FINDER] = {
				20906, 20921, 20939, 20899, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL] = {
				21061, 21058, 20976, 20979,
			},
			[RAID_HEROIC] = {
				21015, 21001, 21036, 21006,
			},
			[RAID_MYTHIC] = {
				21015, 21001, 21036, 21006,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99717] = {
		Items = {
			[RAID_FINDER] = {
				20908, 20918, 20934, 20888, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL] = {
				21062, 21063, 20971, 20981,
			},
			[RAID_HEROIC] = {
				21017, 21003, 21039, 21000,
			},
			[RAID_MYTHIC] = {
				21017, 21003, 21039, 21000,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99714] = {
		Items = {
			[RAID_FINDER] = {
				20904, 20928, 21567, 20900, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL] = {
				20952, 20987, 21502, 20984,
			},
			[RAID_HEROIC] = {
				21019, 21008, 21557, 21004,
			},
			[RAID_MYTHIC] = {
				21019, 21008, 21557, 21004,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99720] = {
		Items = {
			[RAID_FINDER] = {
				20905, 20920, 20938, 20898, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL] = {
				20953, 20988, 20975, 20978,
			},
			[RAID_HEROIC] = {
				21018, 21009, 21035, 21005,
			},
			[RAID_MYTHIC] = {
				21018, 21009, 21035, 21005,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[99726] = {
		Items = {
			[RAID_FINDER] = {
				20907, 20917, 20932, 20891, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL] = {
				20955, 20986, 20977, 20980,
			},
			[RAID_HEROIC] = {
				21016, 21002, 21037, 21007,
			},
			[RAID_MYTHIC] = {
				21016, 21002, 21037, 21007,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Throne of Thunder (LFR 25)
	[95880] = {
		Items = {
			[RAID_FINDER_EXT] = {
				19952, 20049, 19964, -- Paladin, Priest, Warlock Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95956] = {
		Items = {
			[RAID_FINDER_EXT] = {
				19954, 20045, 19960, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95823] = {
		Items = {
			[RAID_FINDER_EXT] = {
				19950, 20047, 19962, -- Paladin, Priest, Warlock Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95856] = {
		Items = {
			[RAID_FINDER_EXT] = {
				19951, 20048, 19963, -- Paladin, Priest, Warlock Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95888] = {
		Items = {
			[RAID_FINDER_EXT] = {
				19953, 20050, 19965, -- Paladin, Priest, Warlock Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[95881] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20077, 19912, 20359, 20257, -- Warrior, Hunter, Shaman, Monk Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95957] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20079, 19914, 20361, 20262, -- Warrior, Hunter, Shaman, Monk Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95824] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20075, 19910, 20362, 20259, -- Warrior, Hunter, Shaman, Monk Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95857] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20076, 19911, 20358, 20260, -- Warrior, Hunter, Shaman, Monk Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95889] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20078, 19913, 20360, 20261, -- Warrior, Hunter, Shaman, Monk Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[95879] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20098, 20476, 20203, 19849, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95955] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20103, 20478, 20199, 19852, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95822] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20100, 20474, 20201, 19851, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95855] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20101, 20475, 20202, 19848, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95887] = {
		Items = {
			[RAID_FINDER_EXT] = {
				20102, 20477, 20204, 19850, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Throne of Thunder (Normal)
	[95577] = {
		Items = {
			[RAID_FINDER] = {
				19935, 20058, 20156,
			},
			[RAID_HEROIC] = {
				19935, 20058, 20156,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95578] = {
		Items = {
			[RAID_FINDER] = {
				19937, 20054, 20159,
			},
			[RAID_HEROIC] = {
				19937, 20054, 20159,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95574] = {
		Items = {
			[RAID_FINDER] = {
				19933, 20056, 20158,
			},
			[RAID_HEROIC] = {
				19933, 20056, 20158,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95575] = {
		Items = {
			[RAID_FINDER] = {
				19934, 20057, 20155,
			},
			[RAID_HEROIC] = {
				19934, 20057, 20155,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[95576] = {
		Items = {
			[RAID_FINDER] = {
				19936, 20059, 20157,
			},
			[RAID_HEROIC] = {
				19936, 20059, 20157,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[95582] = {
		Items = {
			[RAID_FINDER] = {
				20168, 19920, 20313, 20241,
			},
			[RAID_HEROIC] = {
				20168, 19920, 20313, 20241,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95583] = {
		Items = {
			[RAID_FINDER] = {
				20170, 19922, 20343, 20246,
			},
			[RAID_HEROIC] = {
				20170, 19922, 20343, 20246,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95579] = {
		Items = {
			[RAID_FINDER] = {
				20166, 19918, 20344, 20243,
			},
			[RAID_HEROIC] = {
				20166, 19918, 20344, 20243,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95580] = {
		Items = {
			[RAID_FINDER] = {
				20167, 19919, 20341, 20244,
			},
			[RAID_HEROIC] = {
				20167, 19919, 20341, 20244,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[95581] = {
		Items = {
			[RAID_FINDER] = {
				20169, 19921, 20342, 20245,
			},
			[RAID_HEROIC] = {
				20169, 19921, 20342, 20245,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[95571] = {
		Items = {
			[RAID_FINDER] = {
				20082, 20311, 20212, 19858,
			},
			[RAID_HEROIC] = {
				20082, 20311, 20212, 19858,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95573] = {
		Items = {
			[RAID_FINDER] = {
				20087, 20431, 20208, 19861,
			},
			[RAID_HEROIC] = {
				20087, 20431, 20208, 19861,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95569] = {
		Items = {
			[RAID_FINDER] = {
				20084, 20424, 20210, 19860,
			},
			[RAID_HEROIC] = {
				20084, 20424, 20210, 19860,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95570] = {
		Items = {
			[RAID_FINDER] = {
				20085, 20480, 20211, 19857,
			},
			[RAID_HEROIC] = {
				20085, 20480, 20211, 19857,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[95572] = {
		Items = {
			[RAID_FINDER] = {
				20086, 20427, 20213, 19859,
			},
			[RAID_HEROIC] = {
				20086, 20427, 20213, 19859,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Throne of Thunder (Heroic)
	[96624] = {
		Items = {
			[RAID_NORMAL] = {
				19943, 20040, 19972,
			},
			[RAID_MYTHIC] = {
				19943, 20040, 19972,
			},
			[RAID_HEROIC_EXT] = {
				19943, 20040, 19972,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[96700] = {
		Items = {
			[RAID_NORMAL] = {
				19945, 20036, 19975,
			},
			[RAID_MYTHIC] = {
				19945, 20036, 19975,
			},
			[RAID_HEROIC_EXT] = {
				19945, 20036, 19975,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[96567] = {
		Items = {
			[RAID_NORMAL] = {
				19941, 20038, 19974,
			},
			[RAID_MYTHIC] = {
				19941, 20038, 19974,
			},
			[RAID_HEROIC_EXT] = {
				19941, 20038, 19974,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[96600] = {
		Items = {
			[RAID_NORMAL] = {
				19942, 20039, 19971,
			},
			[RAID_MYTHIC] = {
				19942, 20039, 19971,
			},
			[RAID_HEROIC_EXT] = {
				19942, 20039, 19971,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[96632] = {
		Items = {
			[RAID_NORMAL] = {
				19944, 20041, 19973,
			},
			[RAID_MYTHIC] = {
				19944, 20041, 19973,
			},
			[RAID_HEROIC_EXT] = {
				19944, 20041, 19973,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[96625] = {
		Items = {
			[RAID_NORMAL] = {
				20176, 19928, 20350, 20249,
			},
			[RAID_MYTHIC] = {
				20176, 19928, 20350, 20249,
			},
			[RAID_HEROIC_EXT] = {
				20176, 19928, 20350, 20249,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[96701] = {
		Items = {
			[RAID_NORMAL] = {
				20178, 19930, 20352, 20254,
			},
			[RAID_MYTHIC] = {
				20178, 19930, 20352, 20254,
			},
			[RAID_HEROIC_EXT] = {
				20178, 19930, 20352, 20254,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[96568] = {
		Items = {
			[RAID_NORMAL] = {
				20174, 19926, 20353, 20251,
			},
			[RAID_MYTHIC] = {
				20174, 19926, 20353, 20251,
			},
			[RAID_HEROIC_EXT] = {
				20174, 19926, 20353, 20251,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[96601] = {
		Items = {
			[RAID_NORMAL] = {
				20175, 19927, 20349, 20252,
			},
			[RAID_MYTHIC] = {
				20175, 19927, 20349, 20252,
			},
			[RAID_HEROIC_EXT] = {
				20175, 19927, 20349, 20252,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[96633] = {
		Items = {
			[RAID_NORMAL] = {
				20177, 19929, 20351, 20253,
			},
			[RAID_MYTHIC] = {
				20177, 19929, 20351, 20253,
			},
			[RAID_HEROIC_EXT] = {
				20177, 19929, 20351, 20253,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[96623] = {
		Items = {
			[RAID_NORMAL] = {
				20090, 20126, 20221, 19840,
			},
			[RAID_MYTHIC] = {
				20090, 20126, 20221, 19840,
			},
			[RAID_HEROIC_EXT] = {
				20090, 20126, 20221, 19840,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[96699] = {
		Items = {
			[RAID_NORMAL] = {
				20095, 20128, 20217, 19842,
			},
			[RAID_MYTHIC] = {
				20095, 20128, 20217, 19842,
			},
			[RAID_HEROIC_EXT] = {
				20095, 20128, 20217, 19842,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[96566] = {
		Items = {
			[RAID_NORMAL] = {
				20092, 20124, 20219, 19844,
			},
			[RAID_MYTHIC] = {
				20092, 20124, 20219, 19844,
			},
			[RAID_HEROIC_EXT] = {
				20092, 20124, 20219, 19844,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[96599] = {
		Items = {
			[RAID_NORMAL] = {
				20093, 20125, 20220, 19839,
			},
			[RAID_MYTHIC] = {
				20093, 20125, 20220, 19839,
			},
			[RAID_HEROIC_EXT] = {
				20093, 20125, 20220, 19839,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[96631] = {
		Items = {
			[RAID_NORMAL] = {
				20094, 20127, 20222, 19841,
			},
			[RAID_MYTHIC] = {
				20094, 20127, 20222, 19841,
			},
			[RAID_HEROIC_EXT] = {
				20094, 20127, 20222, 19841,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Heart of Fear (LFR)
	[89274] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18036, 18981, 18084, -- Paladin, Priest, Warlock Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89277] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18038, 18980, 18080, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89265] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18034, 17712, 18082, -- Paladin, Priest, Warlock Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89271] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18035, 17713, 18083, -- Paladin, Priest, Warlock Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89268] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18037, 17715, 18982, -- Paladin, Priest, Warlock Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[89275] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18164, 18964, 18960, 18799, -- Warrior, Hunter, Shaman, Monk Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89278] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18166, 18962, 18958, 18803, -- Warrior, Hunter, Shaman, Monk Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89266] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18067, 18965, 18717, 18801, -- Warrior, Hunter, Shaman, Monk Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89272] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18068, 18714, 18716, 18718, -- Warrior, Hunter, Shaman, Monk Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89269] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18165, 18963, 18959, 18802, -- Warrior, Hunter, Shaman, Monk Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[89273] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18968, 18977, 18659, 18973, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89276] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18966, 18975, 18657, 18970, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89264] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18969, 18979, 17946, 18971, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89270] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18715, 18978, 17947, 18974, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89267] = {
		Items = {
			[RAID_FINDER_EXT] = {
				18967, 18976, 18660, 18972, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Heart of Fear (Normal)
	[89235] = {
		Items = {
			[RAID_FINDER] = {
				18021, 18585, 18093,
			},
			[RAID_HEROIC] = {
				18021, 18585, 18093,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89246] = {
		Items = {
			[RAID_FINDER] = {
				18023, 18584, 18089,
			},
			[RAID_HEROIC] = {
				18023, 18584, 18089,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89237] = {
		Items = {
			[RAID_FINDER] = {
				18019, 17694, 18091,
			},
			[RAID_HEROIC] = {
				18019, 17694, 18091,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89240] = {
		Items = {
			[RAID_FINDER] = {
				18020, 17695, 18092,
			},
			[RAID_HEROIC] = {
				18020, 17695, 18092,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89243] = {
		Items = {
			[RAID_FINDER] = {
				18022, 17697, 18094,
			},
			[RAID_HEROIC] = {
				18022, 17697, 18094,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[89236] = {
		Items = {
			[RAID_FINDER] = {
				18158, 18566, 18560, 18593,
			},
			[RAID_HEROIC] = {
				18158, 18566, 18560, 18593,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89247] = {
		Items = {
			[RAID_FINDER] = {
				18160, 18564, 18558, 18591,
			},
			[RAID_HEROIC] = {
				18160, 18564, 18558, 18591,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89238] = {
		Items = {
			[RAID_FINDER] = {
				18156, 18568, 18563, 18595,
			},
			[RAID_HEROIC] = {
				18156, 18568, 18563, 18595,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89241] = {
		Items = {
			[RAID_FINDER] = {
				18157, 18567, 18561, 18594,
			},
			[RAID_HEROIC] = {
				18157, 18567, 18561, 18594,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89244] = {
		Items = {
			[RAID_FINDER] = {
				18159, 18565, 18559, 18592,
			},
			[RAID_HEROIC] = {
				18159, 18565, 18559, 18592,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[89234] = {
		Items = {
			[RAID_FINDER] = {
				18571, 18581, 18589, 18577,
			},
			[RAID_HEROIC] = {
				18571, 18581, 18589, 18577,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89248] = {
		Items = {
			[RAID_FINDER] = {
				18569, 18579, 18586, 18574,
			},
			[RAID_HEROIC] = {
				18569, 18579, 18586, 18574,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89239] = {
		Items = {
			[RAID_FINDER] = {
				18573, 18583, 18587, 18575,
			},
			[RAID_HEROIC] = {
				18573, 18583, 18587, 18575,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89242] = {
		Items = {
			[RAID_FINDER] = {
				18572, 18582, 18590, 18578,
			},
			[RAID_HEROIC] = {
				18572, 18582, 18590, 18578,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89245] = {
		Items = {
			[RAID_FINDER] = {
				18570, 18580, 18588, 18576,
			},
			[RAID_HEROIC] = {
				18570, 18580, 18588, 18576,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Heart of Fear (Heroic)
	[89259] = {
		Items = {
			[RAID_NORMAL] = {
				18044, 18585, 18075,
			},
			[RAID_MYTHIC] = {
				18044, 18585, 18075,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89262] = {
		Items = {
			[RAID_NORMAL] = {
				18046, 19088, 18071,
			},
			[RAID_MYTHIC] = {
				18046, 19088, 18071,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89250] = {
		Items = {
			[RAID_NORMAL] = {
				18042, 17703, 18073,
			},
			[RAID_MYTHIC] = {
				18042, 17703, 18073,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89256] = {
		Items = {
			[RAID_NORMAL] = {
				18043, 17704, 18074,
			},
			[RAID_MYTHIC] = {
				18043, 17704, 18074,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[89253] = {
		Items = {
			[RAID_NORMAL] = {
				18045, 17706, 19058,
			},
			[RAID_MYTHIC] = {
				18045, 17706, 19058,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[89260] = {
		Items = {
			[RAID_NORMAL] = {
				18172, 19063, 19069, 18806,
			},
			[RAID_MYTHIC] = {
				18172, 19063, 19069, 18806,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89263] = {
		Items = {
			[RAID_NORMAL] = {
				18174, 19065, 19095, 18811,
			},
			[RAID_MYTHIC] = {
				18174, 19065, 19095, 18811,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89251] = {
		Items = {
			[RAID_NORMAL] = {
				18170, 19061, 19093, 18808,
			},
			[RAID_MYTHIC] = {
				18170, 19061, 19093, 18808,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89257] = {
		Items = {
			[RAID_NORMAL] = {
				18171, 19062, 19094, 18809,
			},
			[RAID_MYTHIC] = {
				18171, 19062, 19094, 18809,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[89254] = {
		Items = {
			[RAID_NORMAL] = {
				18173, 19064, 19076, 18810,
			},
			[RAID_MYTHIC] = {
				18173, 19064, 19076, 18810,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[89258] = {
		Items = {
			[RAID_NORMAL] = {
				19085, 19036, 18668, 19041,
			},
			[RAID_MYTHIC] = {
				19085, 19036, 18668, 19041,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89261] = {
		Items = {
			[RAID_NORMAL] = {
				19092, 19038, 18664, 19043,
			},
			[RAID_MYTHIC] = {
				19092, 19038, 18664, 19043,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89249] = {
		Items = {
			[RAID_NORMAL] = {
				19089, 19034, 18666, 19039,
			},
			[RAID_MYTHIC] = {
				19089, 19034, 18666, 19039,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89255] = {
		Items = {
			[RAID_NORMAL] = {
				19090, 19035, 18667, 19040,
			},
			[RAID_MYTHIC] = {
				19090, 19035, 18667, 19040,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[89252] = {
		Items = {
			[RAID_NORMAL] = {
				19091, 19037, 18669, 19042,
			},
			[RAID_MYTHIC] = {
				19091, 19037, 18669, 19042,
			},
		},
		Classes = CLASS_GROUP_7,
	},




	-- Dragon Soul (LFR)
	[78869] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16862, 17037, 16549, -- Paladin, Priest, Warlock Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78875] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16864, 17033, 16545, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78863] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16860, 17035, 16547, -- Paladin, Priest, Warlock Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78866] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16861, 17036, 16548, -- Paladin, Priest, Warlock Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78872] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16863, 17038, 16550, -- Paladin, Priest, Warlock Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[78870] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16699, 16852, 16736, -- Warrior, Hunter, Shaman Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78876] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16697, 16855, 17150, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78864] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16701, 16850, 16740, -- Warrior, Hunter, Shaman Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78867] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16700, 16857, 16735, -- Warrior, Hunter, Shaman Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78873] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16698, 16854, 16737, -- Warrior, Hunter, Shaman Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[78868] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16722, 16839, 16649, 16628, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78874] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16724, 16837, 16652, 16631, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78862] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16720, 16841, 16651, 16630, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78865] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16721, 16840, 16648, 16627, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78871] = {
		Items = {
			[RAID_FINDER_EXT] = {
				16723, 17159, 16650, 16629, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Dragon Soul (Normal)
	[78182] = {
		Items = {
			[RAID_FINDER] = {
				16870, 16918, 16558,
			},
			[RAID_HEROIC] = {
				16870, 16918, 16558,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78180] = {
		Items = {
			[RAID_FINDER] = {
				16871, 16916, 16554,
			},
			[RAID_HEROIC] = {
				16871, 16916, 16554,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78184] = {
		Items = {
			[RAID_FINDER] = {
				16868, 16917, 16556,
			},
			[RAID_HEROIC] = {
				16868, 16917, 16556,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78183] = {
		Items = {
			[RAID_FINDER] = {
				16869, 16919, 16557,
			},
			[RAID_HEROIC] = {
				16869, 16919, 16557,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78181] = {
		Items = {
			[RAID_FINDER] = {
				15980, 15979, 16559,
			},
			[RAID_HEROIC] = {
				15980, 15979, 16559,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[78177] = {
		Items = {
			[RAID_FINDER] = {
				16694, 16845, 16752,
			},
			[RAID_HEROIC] = {
				16694, 16845, 16752,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78175] = {
		Items = {
			[RAID_FINDER] = {
				16695, 16847, 16984,
			},
			[RAID_HEROIC] = {
				16695, 16847, 16984,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78179] = {
		Items = {
			[RAID_FINDER] = {
				16692, 16844, 16754,
			},
			[RAID_HEROIC] = {
				16692, 16844, 16754,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78178] = {
		Items = {
			[RAID_FINDER] = {
				16693, 16849, 16753,
			},
			[RAID_HEROIC] = {
				16693, 16849, 16753,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78176] = {
		Items = {
			[RAID_FINDER] = {
				15982, 15985, 15986,
			},
			[RAID_HEROIC] = {
				15982, 15985, 15986,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[78172] = {
		Items = {
			[RAID_FINDER] = {
				16730, 16823, 16667, 16635,
			},
			[RAID_HEROIC] = {
				16730, 16823, 16667, 16635,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78170] = {
		Items = {
			[RAID_FINDER] = {
				16731, 16822, 16669, 16633,
			},
			[RAID_HEROIC] = {
				16731, 16822, 16669, 16633,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78174] = {
		Items = {
			[RAID_FINDER] = {
				16728, 16825, 16668, 16634,
			},
			[RAID_HEROIC] = {
				16728, 16825, 16668, 16634,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78173] = {
		Items = {
			[RAID_FINDER] = {
				16729, 16824, 16666, 16636,
			},
			[RAID_HEROIC] = {
				16729, 16824, 16666, 16636,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78171] = {
		Items = {
			[RAID_FINDER] = {
				15983, 15981, 15978, 15984,
			},
			[RAID_HEROIC] = {
				15983, 15981, 15978, 15984,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Dragon Soul (Heroic)
	[78850] = {
		Items = {
			[RAID_NORMAL] = {
				16876, 17049, 16540,
			},
			[RAID_MYTHIC] = {
				16876, 17049, 16540,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78859] = {
		Items = {
			[RAID_NORMAL] = {
				16878, 17045, 16536,
			},
			[RAID_MYTHIC] = {
				16878, 17045, 16536,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78847] = {
		Items = {
			[RAID_NORMAL] = {
				16874, 17047, 16538,
			},
			[RAID_MYTHIC] = {
				16874, 17047, 16538,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78853] = {
		Items = {
			[RAID_NORMAL] = {
				16875, 17048, 16539,
			},
			[RAID_MYTHIC] = {
				16875, 17048, 16539,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[78856] = {
		Items = {
			[RAID_NORMAL] = {
				16877, 17050, 16541,
			},
			[RAID_MYTHIC] = {
				16877, 17050, 16541,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[78851] = {
		Items = {
			[RAID_NORMAL] = {
				16686, 16816, 16745,
			},
			[RAID_MYTHIC] = {
				16686, 16816, 16745,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78860] = {
		Items = {
			[RAID_NORMAL] = {
				16688, 16819, 17149,
			},
			[RAID_MYTHIC] = {
				16688, 16819, 17149,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78848] = {
		Items = {
			[RAID_NORMAL] = {
				16684, 16814, 16741,
			},
			[RAID_MYTHIC] = {
				16684, 16814, 16741,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78854] = {
		Items = {
			[RAID_NORMAL] = {
				16685, 16821, 16746,
			},
			[RAID_MYTHIC] = {
				16685, 16821, 16746,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[78857] = {
		Items = {
			[RAID_NORMAL] = {
				16687, 16818, 16744,
			},
			[RAID_MYTHIC] = {
				16687, 16818, 16744,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[78852] = {
		Items = {
			[RAID_NORMAL] = {
				16714, 16831, 16658, 16618,
			},
			[RAID_MYTHIC] = {
				16714, 16831, 16658, 16618,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78861] = {
		Items = {
			[RAID_NORMAL] = {
				16716, 16829, 16661, 16613,
			},
			[RAID_MYTHIC] = {
				16716, 16829, 16661, 16613,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78849] = {
		Items = {
			[RAID_NORMAL] = {
				16712, 16833, 16660, 16623,
			},
			[RAID_MYTHIC] = {
				16712, 16833, 16660, 16623,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78855] = {
		Items = {
			[RAID_NORMAL] = {
				16713, 16832, 16657, 16615,
			},
			[RAID_MYTHIC] = {
				16713, 16832, 16657, 16615,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[78858] = {
		Items = {
			[RAID_NORMAL] = {
				16715, 16830, 16659, 16614,
			},
			[RAID_MYTHIC] = {
				16715, 16830, 16659, 16614,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Firelands (Normal) (only helm/shoulders)
	[71675] = {
		Items = {
			[RAID_NORMAL] = {
				15681, 15761, 15821, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_HEROIC] = {
				15674, 15754, 15918,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[71681] = {
		Items = {
			[RAID_NORMAL] = {
				15683, 15764, 15879, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				15676, 15757, 15945,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[71682] = {
		Items = {
			[RAID_NORMAL] = {
				15768, 15722, 15892, -- Warrior, Hunter, Shaman Head Slot IDs
			},
			[RAID_HEROIC] = {
				15783, 15729, 15933,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[71688] = {
		Items = {
			[RAID_NORMAL] = {
				15638, 15723, 15814, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				15785, 15731, 15922,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[71668] = {
		Items = {
			[RAID_NORMAL] = {
				15642, 15635, 15707, 15829, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_HEROIC] = {
				15649, 15801, 15690, 15856,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[71674] = {
		Items = {
			[RAID_NORMAL] = {
				15644, 15795, 15710, 15826, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				15651, 15803, 15693, 15860,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Firelands (Heroic)
	[71677] = {
		Items = {
			[RAID_NORMAL] = {
				15681, 15761, 15821, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_HEROIC] = {
				15674, 15754, 15918,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[71680] = {
		Items = {
			[RAID_NORMAL] = {
				15683, 15764, 15879, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				15676, 15757, 15945,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[71679] = {
		Items = {
			[RAID_NORMAL] = {
				15685, 15763, 15830, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_HEROIC] = {
				15678, 15756, 15913,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[71676] = {
		Items = {
			[RAID_NORMAL] = {
				15530, 15535, 15536, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_HEROIC] = {
				15673, 15753, 15943,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[71678] = {
		Items = {
			[RAID_NORMAL] = {
				15682, 15762, 15878, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_HEROIC] = {
				15675, 15755, 15944,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[71684] = {
		Items = {
			[RAID_NORMAL] = {
				15768, 15722, 15892, -- Warrior, Hunter, Shaman Head Slot IDs
			},
			[RAID_HEROIC] = {
				15783, 15729, 15933,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[71687] = {
		Items = {
			[RAID_NORMAL] = {
				15638, 15723, 15814, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				15785, 15731, 15922,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[71686] = {
		Items = {
			[RAID_NORMAL] = {
				15769, 15721, 15875, -- Warrior, Hunter, Shaman Chest Slot IDs
			},
			[RAID_HEROIC] = {
				15781, 15727, 15929,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[71683] = {
		Items = {
			[RAID_NORMAL] = {
				15528, 15531, 15532, -- Warrior, Hunter, Shaman Hand Slot IDs
			},
			[RAID_HEROIC] = {
				15782, 15728, 15921,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[71685] = {
		Items = {
			[RAID_NORMAL] = {
				15767, 15637, 15831, -- Warrior, Hunter, Shaman Leg Slot IDs
			},
			[RAID_HEROIC] = {
				15784, 15730, 15916,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[71670] = {
		Items = {
			[RAID_NORMAL] = {
				15642, 15635, 15707, 15829, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_HEROIC] = {
				15649, 15801, 15690, 15856,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[71673] = {
		Items = {
			[RAID_NORMAL] = {
				15644, 15795, 15710, 15826, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				15651, 15803, 15693, 15860,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[71672] = {
		Items = {
			[RAID_NORMAL] = {
				15641, 15796, 15709, 15820, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_HEROIC] = {
				15647, 15799, 15692, 15857,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[71669] = {
		Items = {
			[RAID_NORMAL] = {
				15533, 15529, 15706, 15534, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_HEROIC] = {
				15648, 15800, 15689, 15858,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[71671] = {
		Items = {
			[RAID_NORMAL] = {
				15643, 15639, 15708, 15836, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_HEROIC] = {
				15650, 15802, 15691, 15859,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Bastion of Twilight (Normal) (these items are "removed" and weird but show in journals)
	[63683] = {
		Items = {
			[RAID_FINDER] = {
				14049, 14024, 14098, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_HEROIC] = {
				14049, 14024, 14098,
			},
		},
		Classes = CLASS_GROUP_5,

	},
	[64315] = {
		Items = {
			[RAID_FINDER] = {
				13974, 13993, 14099, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				13974, 13993, 14099,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[63684] = {
		Items = {
			[RAID_FINDER] = {
				13997, 14048, 14036, -- Warrior, Hunter, Shaman Head Slot IDs
			},
			[RAID_HEROIC] = {
				13997, 14048, 14036,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[64316] = {
		Items = {
			[RAID_FINDER] = {
				14004, 13964, 14050, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				14004, 13964, 14050,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[63682] = {
		Items = {
			[RAID_FINDER] = {
				14041, 14040, 13963, 13975, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_HEROIC] = {
				14041, 14040, 13963, 13975,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[64314] = {
		Items = {
			[RAID_FINDER] = {
				13950, 14082, 13984, 13962, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_HEROIC] = {
				13950, 14082, 13984, 13962,
			},
		},
		Classes = CLASS_GROUP_7,
	},

	-- Bastion of Twilight (Heroic)
	[65001] = {
		Items = {
			[RAID_NORMAL] = {
				14755, 14710, 14775,
			},
			[RAID_MYTHIC] = {
				14755, 14710, 14775,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[65088] = {
		Items = {
			[RAID_NORMAL] = {
				14738, 14723, 14776,
			},
			[RAID_MYTHIC] = {
				14738, 14723, 14776,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[67423] = {
		Items = {
			[RAID_NORMAL] = {
				14722, 14763, 14705,
			},
			[RAID_MYTHIC] = {
				14722, 14763, 14705,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[67429] = {
		Items = {
			[RAID_NORMAL] = {
				14715, 14736, 14759,
			},
			[RAID_MYTHIC] = {
				14715, 14736, 14759,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[67428] = {
		Items = {
			[RAID_NORMAL] = {
				14765, 14716, 14724,
			},
			[RAID_MYTHIC] = {
				14765, 14716, 14724,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[65000] = {
		Items = {
			[RAID_NORMAL] = {
				14719, 14757, 14764,
			},
			[RAID_MYTHIC] = {
				14719, 14757, 14764,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[65087] = {
		Items = {
			[RAID_NORMAL] = {
				14712, 14743, 14754,
			},
			[RAID_MYTHIC] = {
				14712, 14743, 14754,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[67424] = {
		Items = {
			[RAID_NORMAL] = {
				14761, 14718, 14703,
			},
			[RAID_MYTHIC] = {
				14761, 14718, 14703,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[67430] = {
		Items = {
			[RAID_NORMAL] = {
				14741, 14767, 14730,
			},
			[RAID_MYTHIC] = {
				14741, 14767, 14730,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[67427] = {
		Items = {
			[RAID_NORMAL] = {
				14758, 14090, 14751,
			},
			[RAID_MYTHIC] = {
				14758, 14090, 14751,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[65002] = {
		Items = {
			[RAID_NORMAL] = {
				14760, 14749, 14095, 14737,
			},
			[RAID_MYTHIC] = {
				14760, 14749, 14095, 14737,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[65089] = {
		Items = {
			[RAID_NORMAL] = {
				14746, 14752, 14729, 14706,
			},
			[RAID_MYTHIC] = {
				14746, 14752, 14729, 14706,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[67425] = {
		Items = {
			[RAID_NORMAL] = {
				14731, 14733, 14709, 14725,
			},
			[RAID_MYTHIC] = {
				14731, 14733, 14709, 14725,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[67431] = {
		Items = {
			[RAID_NORMAL] = {
				14742, 14772, 14773, 14753,
			},
			[RAID_MYTHIC] = {
				14742, 14772, 14773, 14753,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[67426] = {
		Items = {
			[RAID_NORMAL] = {
				14720, 14732, 14774, 14714,
			},
			[RAID_MYTHIC] = {
				14720, 14732, 14774, 14714,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	--[[
	-- Icecrown Citadel (10 Heroic / 25 Normal)
	[52027] = {
		Items = {
			[RAID_HEROIC] = { -- RAID_NORMAL (10)
				12411, 12280, 12416, 12411,  -- Paladin, Priest, Warlock Head Slot IDs
				12240, 12263, 12438, 12576,
				12498, 12475, 12586,		 -- Paladin, Priest, Warlock Head Slot IDs
				12409, 12419, 12374, 12409,	 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12240, 12438, 12576, 12465,
				12452, 12588, 12459,		 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12413, 12418, 12373, 12413,	 -- Paladin, Priest, Warlock Chest Slot IDs
				12263, 12341, 12577, 12577,
				12485, 12507, 12476,		 -- Paladin, Priest, Warlock Chest Slot IDs
				12412, 12415, 12370, 12412,	 -- Paladin, Priest, Warlock Hand Slot IDs
				12248, 12344, 12580, 12580,
				12469, 12509, 12493,		 -- Paladin, Priest, Warlock Hand Slot IDs
				12410, 12417, 12372, 12410,	 -- Paladin, Priest, Warlock Leg Slot IDs
				12225, 12575, 12578, 12578,
				12590, 12589, 12493,		 -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_MYTHIC] = { -- 25 Heroic
				12411, 12280, 12416, 12411,	 -- Paladin, Priest, Warlock Head Slot IDs
				12240, 12263, 12438, 12576,
				12498, 12475, 12586,		 -- Paladin, Priest, Warlock Head Slot IDs
				12409, 12419, 12374, 12409,	 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12240, 12438, 12576, 12465,
				12452, 12588, 12459,		 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12413, 12418, 12373, 12413,	 -- Paladin, Priest, Warlock Chest Slot IDs
				12263, 12341, 12577, 12577,
				12485, 12507, 12476,		 -- Paladin, Priest, Warlock Chest Slot IDs
				12412, 12415, 12370, 12412,	 -- Paladin, Priest, Warlock Hand Slot IDs
				12248, 12344, 12580, 12580,
				12469, 12509, 12493,		 -- Paladin, Priest, Warlock Hand Slot IDs
				12410, 12417, 12372, 12410,	 -- Paladin, Priest, Warlock Leg Slot IDs
				12225, 12575, 12578, 12578,
				12590, 12589, 12493,		 -- Paladin, Priest, Warlock Leg Slot IDs
			},
		},
		--Classes = CLASS_GROUP_5,
	},

	[52026] = {
		Items = {
			[RAID_HEROIC] = { -- RAID_NORMAL_10
				12291, 12310, 12538,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12243, 12234, 12355,
				12582, 12443, 12458,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12293, 12312, 12550,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12253, 12261, 12279,
				12585, 12481, 26844,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12289, 12313, 12547,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12233, 12272, 12345,
				12581, 12597, 12510,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12290, 12309, 12548,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12271, 12350, 12282,
				12583, 12453, 12500,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12292, 12311, 12549,		 -- Warrior, Hunter, Shaman Leg Slot IDs
				12226, 12224, 12223,
				12584, 12466, 12587,		 -- Warrior, Hunter, Shaman Leg Slot IDs
			},
			[RAID_MYTHIC] = { -- 25 Heroic
				12291, 12310, 12538,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12243, 12234, 12355,
				12582, 12443, 12458,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12293, 12312, 12550,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12253, 12261, 12279,
				12585, 12481, 26844,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12289, 12313, 12547,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12233, 12272, 12345,
				12581, 12597, 12510,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12290, 12309, 12548,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12271, 12350, 12282,
				12583, 12453, 12500,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12292, 12311, 12549,		 -- Warrior, Hunter, Shaman Leg Slot IDs
				12226, 12224, 12223,
				12584, 12466, 12587,		 -- Warrior, Hunter, Shaman Leg Slot IDs
			},
		},
		--Classes = CLASS_GROUP_6,
	},

	[52025] = {
		Items = {
			[RAID_HEROIC] = { -- RAID_NORMAL_10
				12296, 12300, 12388, 12306,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12288, 12569, 12574, 12262,
				12505, 12463, 12592, 12484,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12303, 12302, 12391, 12308,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12244, 12567, 12573, 12340,
				12467, 12474, 12595, 12506,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12294, 12298, 12390, 12546,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12252, 12571, 12553, 12249,
				12473, 12444, 12594, 12468,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12295, 12299, 12387, 12305,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12260, 12570, 12256, 12239,
				12482, 12491, 12591, 12450,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12297, 12301, 12389, 12307, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
				12222, 12568, 12215, 12221,
				12495, 12448, 12593, 12494,		 -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_MYTHIC] = { -- 25 Heroic
				12296, 12300, 12388, 12306,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12288, 12569, 12574, 12262,
				12505, 12463, 12592, 12484,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12303, 12302, 12391, 12308,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12244, 12567, 12573, 12340,
				12467, 12474, 12595, 12506,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12294, 12298, 12390, 12546,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12252, 12571, 12553, 12249,
				12473, 12444, 12594, 12468,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12295, 12299, 12387, 12305,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12260, 12570, 12256, 12239,
				12482, 12491, 12591, 12450,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12297, 12301, 12389, 12307,		 -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
				12222, 12568, 12215, 12221,
				12495, 12448, 12593, 12494,		 -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
		},
		--Classes = CLASS_GROUP_7,
	},


	-- Icecrown Citadel (25 Heroic)
	[52030] = {
		Items = {
			[RAID_MYTHIC] = { -- 25 Heroic
				12411, 12280, 12416, 12411,		 -- Paladin, Priest, Warlock Head Slot IDs
				12240, 12263, 12438, 12576,
				12498, 12475, 12586,			 -- Paladin, Priest, Warlock Head Slot IDs
				12409, 12419, 12374, 12409,		 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12240, 12438, 12576, 12465,
				12452, 12588, 12459,			 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12413, 12418, 12373, 12413,		 -- Paladin, Priest, Warlock Chest Slot IDs
				12263, 12341, 12577, 12577,
				12485, 12507, 12476,			 -- Paladin, Priest, Warlock Chest Slot IDs
				12412, 12415, 12370, 12412,		 -- Paladin, Priest, Warlock Hand Slot IDs
				12248, 12344, 12580, 12580,
				12469, 12509, 12493,			 -- Paladin, Priest, Warlock Hand Slot IDs
				12410, 12417, 12372, 12410,		 -- Paladin, Priest, Warlock Leg Slot IDs
				12225, 12575, 12578, 12578,
				12590, 12589, 12493,			 -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_HEROIC] = { -- RAID_NORMAL (10)
				12411, 12280, 12416, 12411,		 -- Paladin, Priest, Warlock Head Slot IDs
				12240, 12263, 12438, 12576,
				12498, 12475, 12586,			 -- Paladin, Priest, Warlock Head Slot IDs
				12409, 12419, 12374, 12409,		 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12240, 12438, 12576, 12465,
				12452, 12588, 12459,			 -- Paladin, Priest, Warlock Shoulder Slot IDs
				12413, 12418, 12373, 12413,		 -- Paladin, Priest, Warlock Chest Slot IDs
				12263, 12341, 12577, 12577,
				12485, 12507, 12476,			 -- Paladin, Priest, Warlock Chest Slot IDs
				12412, 12415, 12370, 12412,		 -- Paladin, Priest, Warlock Hand Slot IDs
				12248, 12344, 12580, 12580,
				12469, 12509, 12493,			 -- Paladin, Priest, Warlock Hand Slot IDs
				12410, 12417, 12372, 12410,		 -- Paladin, Priest, Warlock Leg Slot IDs
				12225, 12575, 12578, 12578,
				12590, 12589, 12493,			 -- Paladin, Priest, Warlock Leg Slot IDs
			},
		},
		--Classes = CLASS_GROUP_5,
	},

	[52029] = {
		Items = {
			[RAID_MYTHIC] = { -- 25 Heroic
				12291, 12310, 12538,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12243, 12234, 12355,
				12582, 12443, 12458,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12293, 12312, 12550,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12253, 12261, 12279,
				12585, 12481, 26844,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12289, 12313, 12547,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12233, 12272, 12345,
				12581, 12597, 12510,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12290, 12309, 12548,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12271, 12350, 12282,
				12583, 12453, 12500,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12292, 12311, 12549,		 -- Warrior, Hunter, Shaman Leg Slot IDs
				12226, 12224, 12223,
				12584, 12466, 12587,		 -- Warrior, Hunter, Shaman Leg Slot IDs
			},
			[RAID_HEROIC] = { -- RAID_NORMAL_10
				12291, 12310, 12538,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12243, 12234, 12355,
				12582, 12443, 12458,		 -- Warrior, Hunter, Shaman Head Slot IDs
				12293, 12312, 12550,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12253, 12261, 12279,
				12585, 12481, 26844,		 -- Warrior, Hunter, Shaman Shoulder Slot IDs
				12289, 12313, 12547,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12233, 12272, 12345,
				12581, 12597, 12510,		 -- Warrior, Hunter, Shaman Chest Slot IDs
				12290, 12309, 12548,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12271, 12350, 12282,
				12583, 12453, 12500,		 -- Warrior, Hunter, Shaman Hand Slot IDs
				12292, 12311, 12549,		 -- Warrior, Hunter, Shaman Leg Slot IDs
				12226, 12224, 12223,
				12584, 12466, 12587,		 -- Warrior, Hunter, Shaman Leg Slot IDs
			},
		},
		--Classes = CLASS_GROUP_6,
	},

	[52028] = {
		Items = {
			[RAID_MYTHIC] = { -- 25 Heroic
				12296, 12300, 12388, 12306,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12288, 12569, 12574, 12262,
				12505, 12463, 12592, 12484,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12303, 12302, 12391, 12308,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12244, 12567, 12573, 12340,
				12467, 12474, 12595, 12506,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12294, 12298, 12390, 12546,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12252, 12571, 12553, 12249,
				12473, 12444, 12594, 12468,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12295, 12299, 12387, 12305,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12260, 12570, 12256, 12239,
				12482, 12491, 12591, 12450,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12297, 12301, 12389, 12307,		 -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
				12222, 12568, 12215, 12221,
				12495, 12448, 12593, 12494,		 -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_HEROIC] = { -- RAID_NORMAL_10
				12296, 12300, 12388, 12306,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12288, 12569, 12574, 12262,
				12505, 12463, 12592, 12484,		 -- Rogue, Death Knight, Mage, Druid Head Slot IDs
				12303, 12302, 12391, 12308,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12244, 12567, 12573, 12340,
				12467, 12474, 12595, 12506,		 -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
				12294, 12298, 12390, 12546,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12252, 12571, 12553, 12249,
				12473, 12444, 12594, 12468,		 -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
				12295, 12299, 12387, 12305,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12260, 12570, 12256, 12239,
				12482, 12491, 12591, 12450,		 -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
				12297, 12301, 12389, 12307,		 -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
				12222, 12568, 12215, 12221,
				12495, 12448, 12593, 12494,		 -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
		},
		--Classes = CLASS_GROUP_7,
	},
	]]


	-- Ulduar (10)
	[45647] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11421, 11427, 11443, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11421, 11427, 11443,
			},
			[RAID_MYTHIC] = {
				11421, 11427, 11443,
			},
			[RAID_HEROIC] = {
				11421, 11427, 11443,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45659] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11422, 11431, 11447, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11422, 11431, 11447,
			},
			[RAID_MYTHIC] = {
				11422, 11431, 11447,
			},
			[RAID_HEROIC] = {
				11422, 11431, 11447,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45635] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11423, 11430, 11446, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11423, 11430, 11446,
			},
			[RAID_MYTHIC] = {
				11423, 11430, 11446,
			},
			[RAID_HEROIC] = {
				11423, 11430, 11446,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45644] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11419, 11428, 11444, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11419, 11428, 11444,
			},
			[RAID_MYTHIC] = {
				11419, 11428, 11444,
			},
			[RAID_HEROIC] = {
				11419, 11428, 11444,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45650] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11420, 11429, 11445, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11420, 11429, 11445,
			},
			[RAID_MYTHIC] = {
				11420, 11429, 11445,
			},
			[RAID_HEROIC] = {
				11420, 11429, 11445,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[45648] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11450, 11411, 11438, -- Warrior, Hunter, Shaman Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11450, 11411, 11438,
			},
			[RAID_MYTHIC] = {
				11450, 11411, 11438,
			},
			[RAID_HEROIC] = {
				11450, 11411, 11438,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45660] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11453, 11413, 11440, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11453, 11413, 11440,
			},
			[RAID_MYTHIC] = {
				11453, 11413, 11440,
			},
			[RAID_HEROIC] = {
				11453, 11413, 11440,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45636] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11449, 11414, 11441, -- Warrior, Hunter, Shaman Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11449, 11414, 11441,
			},
			[RAID_MYTHIC] = {
				11449, 11414, 11441,
			},
			[RAID_HEROIC] = {
				11449, 11414, 11441,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45645] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11451, 11410, 11437, -- Warrior, Hunter, Shaman Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11451, 11410, 11437,
			},
			[RAID_MYTHIC] = {
				11451, 11410, 11437,
			},
			[RAID_HEROIC] = {
				11451, 11410, 11437,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45651] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11452, 11412, 11439, -- Warrior, Hunter, Shaman Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11452, 11412, 11439,
			},
			[RAID_MYTHIC] = {
				11452, 11412, 11439,
			},
			[RAID_HEROIC] = {
				11452, 11412, 11439,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[45649] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11434, 11400, 11415, 11405, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11434, 11400, 11415, 11405,
			},
			[RAID_MYTHIC] = {
				11434, 11400, 11415, 11405,
			},
			[RAID_HEROIC] = {
				11434, 11400, 11415, 11405,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45661] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11436, 11403, 11418, 11408, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11436, 11403, 11418, 11408,
			},
			[RAID_MYTHIC] = {
				11436, 11403, 11418, 11408,
			},
			[RAID_HEROIC] = {
				11436, 11403, 11418, 11408,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45637] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11432, 11399, 11417, 11409, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11432, 11399, 11417, 11409,
			},
			[RAID_MYTHIC] = {
				11432, 11399, 11417, 11409,
			},
			[RAID_HEROIC] = {
				11432, 11399, 11417, 11409,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45646] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11433, 11401, 11652, 11404, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11433, 11401, 11652, 11404,
			},
			[RAID_MYTHIC] = {
				11433, 11401, 11652, 11404,
			},
			[RAID_HEROIC] = {
				11433, 11401, 11652, 11404,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45652] = {
		Items = {
			[RAID_NORMAL] = { -- RAID_NORMAL
				11435, 11402, 11416, 11406, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				11435, 11402, 11416, 11406,
			},
			[RAID_MYTHIC] = {
				11435, 11402, 11416, 11406,
			},
			[RAID_HEROIC] = {
				11435, 11402, 11416, 11406,
			},
		},
		Classes = CLASS_GROUP_7,
	},



	-- Ulduar (25)
	[45638] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11668, 11678, 11657, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11668, 11678, 11657,
			},
			[RAID_MYTHIC] = {
				11668, 11678, 11657,
			},
			[RAID_HEROIC] = {
				11668, 11678, 11657,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45656] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11664, 11675, 11655, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11664, 11675, 11655,
			},
			[RAID_MYTHIC] = {
				11664, 11675, 11655,
			},
			[RAID_HEROIC] = {
				11664, 11675, 11655,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45632] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11666, 11676, 11656, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11666, 11676, 11656,
			},
			[RAID_MYTHIC] = {
				11666, 11676, 11656,
			},
			[RAID_HEROIC] = {
				11666, 11676, 11656,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45641] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11667, 11674, 11654, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11667, 11674, 11654,
			},
			[RAID_MYTHIC] = {
				11667, 11674, 11654,
			},
			[RAID_HEROIC] = {
				11667, 11674, 11654,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[45653] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11665, 11677, 11566, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11665, 11677, 11566,
			},
			[RAID_MYTHIC] = {
				11665, 11677, 11566,
			},
			[RAID_HEROIC] = {
				11665, 11677, 11566,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[45639] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11663, 11659, 11681, -- Warrior, Hunter, Shaman Head Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11663, 11659, 11681,
			},
			[RAID_MYTHIC] = {
				11663, 11659, 11681,
			},
			[RAID_HEROIC] = {
				11663, 11659, 11681,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45657] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11662, 11660, 11683, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11662, 11660, 11683,
			},
			[RAID_MYTHIC] = {
				11662, 11660, 11683,
			},
			[RAID_HEROIC] = {
				11662, 11660, 11683,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45633] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11661, 11658, 11679, -- Warrior, Hunter, Shaman Chest Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11661, 11658, 11679,
			},
			[RAID_MYTHIC] = {
				11661, 11658, 11679,
			},
			[RAID_HEROIC] = {
				11661, 11658, 11679,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45642] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11560, 11561, 11680, -- Warrior, Hunter, Shaman Hand Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11560, 11561, 11680,
			},
			[RAID_MYTHIC] = {
				11560, 11561, 11680,
			},
			[RAID_HEROIC] = {
				11560, 11561, 11680,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[45654] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11563, 11565, 11682, -- Warrior, Hunter, Shaman Leg Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11563, 11565, 11682,
			},
			[RAID_MYTHIC] = {
				11563, 11565, 11682,
			},
			[RAID_HEROIC] = {
				11563, 11565, 11682,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[45640] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11647, 10325, 11650, 11673, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11647, 10325, 11650, 11673,
			},
			[RAID_MYTHIC] = {
				11647, 10325, 11650, 11673,
			},
			[RAID_HEROIC] = {
				11647, 10325, 11650, 11673,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45658] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11649, 10328, 10463, 11669, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11649, 10328, 10463, 11669,
			},
			[RAID_MYTHIC] = {
				11649, 10328, 10463, 11669,
			},
			[RAID_HEROIC] = {
				11649, 10328, 10463, 11669,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45634] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11645, 10326, 11651, 11671, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11645, 10326, 11651, 11671,
			},
			[RAID_MYTHIC] = {
				11645, 10326, 11651, 11671,
			},
			[RAID_HEROIC] = {
				11645, 10326, 11651, 11671,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45643] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11646, 10329, 10461, 11670, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11646, 10329, 10461, 11670,
			},
			[RAID_MYTHIC] = {
				11646, 10329, 10461, 11670,
			},
			[RAID_HEROIC] = {
				11646, 10329, 10461, 11670,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[45655] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				11648, 10327, 11653, 11672, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL] = { -- RAID_NORMAL
				11648, 10327, 11653, 11672,
			},
			[RAID_MYTHIC] = {
				11648, 10327, 11653, 11672,
			},
			[RAID_HEROIC] = {
				11648, 10327, 11653, 11672,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Naxxramas (10)
	[40616] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10194, 10157, 10151, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10427, 10157, 10363,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40622] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10197, 10160, 10154, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10429, 10374, 10366,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40610] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10195, 10158, 10152, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10425, 10373, 10365,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40613] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10198, 10161, 10155, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10426, 10371, 10362,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40619] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10196, 10159, 10153, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10428, 10372, 10364,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[40617] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10184, 10173, 10178, -- Warrior, Hunter, Shaman Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10408, 10397, 10402,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40623] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10187, 10176, 10181, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10410, 10399, 10404,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40611] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10185, 10174, 10179, -- Warrior, Hunter, Shaman Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10406, 10395, 10400,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40614] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10188, 10177, 10182, -- Warrior, Hunter, Shaman Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10407, 10396, 10401,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40620] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10186, 10175, 10180, -- Warrior, Hunter, Shaman Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10409, 10398, 10403,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[40618] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10170, 10191, 10146, 10162, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10392, 10418, 10358, 10378,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40624] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10172, 10193, 10149, 10165, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10394, 10420, 10361, 10382,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40612] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10168, 10189, 10147, 10167, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10389, 10415, 10360, 10380,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40615] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10169, 10190, 10150, 10166, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10390, 10416, 10357, 10377,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40621] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10171, 10192, 10148, 10164, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10393, 10419, 10359, 10379,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Naxxramas (25)
	[40631] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10194, 10157, 10151, -- Paladin, Priest, Warlock Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10427, 10157, 10363,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40637] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10197, 10160, 10154, -- Paladin, Priest, Warlock Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10429, 10374, 10366,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40625] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10195, 10158, 10152, -- Paladin, Priest, Warlock Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10425, 10373, 10365,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40628] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10198, 10161, 10155, -- Paladin, Priest, Warlock Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10426, 10371, 10362,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[40634] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10196, 10159, 10153, -- Paladin, Priest, Warlock Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10428, 10372, 10364,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	[40632] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10184, 10173, 10178, -- Warrior, Hunter, Shaman Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10408, 10397, 10402,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40638] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10187, 10176, 10181, -- Warrior, Hunter, Shaman Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10410, 10399, 10404,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40626] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10185, 10174, 10179, -- Warrior, Hunter, Shaman Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10406, 10395, 10400,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40629] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10188, 10177, 10182, -- Warrior, Hunter, Shaman Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10407, 10396, 10401,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[40635] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10186, 10175, 10180, -- Warrior, Hunter, Shaman Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10409, 10398, 10403,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	[40633] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10170, 10191, 10146, 10162, -- Rogue, Death Knight, Mage, Druid Head Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10392, 10418, 10358, 10378,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40639] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10172, 10193, 10149, 10165, -- Rogue, Death Knight, Mage, Druid Shoulder Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10394, 10420, 10361, 10382,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40627] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10168, 10189, 10147, 10167, -- Rogue, Death Knight, Mage, Druid Chest Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10389, 10415, 10360, 10380,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40630] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10169, 10190, 10150, 10166, -- Rogue, Death Knight, Mage, Druid Hand Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10390, 10416, 10357, 10377,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[40636] = {
		Items = {
			[RAID_NORMAL_10] = { -- RAID_NORMAL_10
				10171, 10192, 10148, 10164, -- Rogue, Death Knight, Mage, Druid Leg Slot IDs
			},
			[RAID_NORMAL_25] = { -- RAID_NORMAL_25
				10393, 10419, 10359, 10379,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Blackrock Foundry

	--mythic
	-- warrior, hunter, shaman, monk
	[120252] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23156, 23912, 23676, 23638,
			},
			[RAID_MYTHIC] = {
				23156, 23912, 23676, 23638,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120253] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23157, 23913, 23677, 23470,
			},
			[RAID_MYTHIC] = {
				23157, 23913, 23677, 23470,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120255] = { -- head
		Items = {
			[QUESTREWARD] = {
				23151, 23914, 23678, 23471,
			},
			[RAID_MYTHIC] = {
				23151, 23914, 23678, 23471,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120254] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23158, 23919, 23472, 23689,
			},
			[RAID_MYTHIC] = {
				23158, 23919, 23472, 23689,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120256] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23152, 23920, 23679, 23473,
			},
			[RAID_MYTHIC] = {
				23152, 23920, 23679, 23473,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	--Rogue, Death Knight, Mage, Druid
	[120251] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23487, 24085, 23606, 23663,
			},
			[RAID_MYTHIC] = {
				23487, 24085, 23606, 23663,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120247] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23488, 24086, 23603, 23657,
			},
			[RAID_MYTHIC] = {
				23488, 24086, 23603, 23657,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120248] = { -- head
		Items = {
			[QUESTREWARD] = {
				23489, 24087, 23604, 23658,
			},
			[RAID_MYTHIC] = {
				23489, 24087, 23604, 23658,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120249] = { -- legs
		Items = {
			[QUESTREWARD] = {
				23490, 24088, 23605, 23660,
			},
			[RAID_MYTHIC] = {
				23490, 24088, 23605, 23660,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120250] = { -- shoulders
		Items = {
			[QUESTREWARD] = {
				23491, 24089, 23607, 23661,
			},
			[RAID_MYTHIC] = {
				23491, 24089, 23607, 23661,
			},
		},
		Classes = CLASS_GROUP_7,
	},

	--Paladin, Priest, Warlock
	[120242] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23219, 24033, 23868,
			},
			[RAID_MYTHIC] = {
				23219, 24033, 23868,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120243] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23220, 24028, 23865,
			},
			[RAID_MYTHIC] = {
				23220, 24028, 23865,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120245] = { -- head
		Items = {
			[QUESTREWARD] = {
				23221, 24029, 23866,
			},
			[RAID_MYTHIC] = {
				23221, 24029, 23866,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120244] = { -- legs
		Items = {
			[QUESTREWARD] = {
				23222, 24030, 23867,
			},
			[RAID_MYTHIC] = {
				23222, 24030, 23867,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120246] = { -- shoulders
		Items = {
			[QUESTREWARD] = {
				23223, 24031, 23869,
			},
			[RAID_MYTHIC] = {
				23223, 24031, 23869,
			},
		},
		Classes = CLASS_GROUP_5,
	},


	--Heroic
	-- warrior, hunter, shaman, monk
	[120237] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23111, 23767, 23373, 23469,
			},
			[RAID_HEROIC] = {
				23111, 23767, 23373, 23469,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120238] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23112, 23768, 23378, 23470,
			},
			[RAID_HEROIC] = {
				23112, 23768, 23378, 23470,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120240] = { -- head
		Items = {
			[QUESTREWARD] = {
				23113, 23769, 23370, 23471,
			},
			[RAID_HEROIC] = {
				23113, 23769, 23370, 23471,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120239] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23114, 23770, 23375, 23472,
			},
			[RAID_HEROIC] = {
				23114, 23770, 23375, 23472,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120241] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23115, 23771, 23371, 23473,
			},
			[RAID_HEROIC] = {
				23115, 23771, 23371, 23473,
			},
		},
		Classes = CLASS_GROUP_6,
	},


	-- Rogue, Death Knight, Mage, Druid
	[120236] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23138, 23896, 23424, 23666,
			},
			[RAID_HEROIC] = {
				23138, 23896, 23424, 23666,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120232] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23137, 23897, 23421, 23667,
			},
			[RAID_HEROIC] = {
				23137, 23897, 23421, 23667,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120233] = { -- head
		Items = {
			[QUESTREWARD] = {
				23140, 23898, 23422, 23668,
			},
			[RAID_HEROIC] = {
				23140, 23898, 23422, 23668,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120234] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23136, 23900, 23423, 23669,
			},
			[RAID_HEROIC] = {
				23136, 23900, 23423, 23669,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120235] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23135, 23899, 23425, 23670,
			},
			[RAID_HEROIC] = {
				23135, 23899, 23425, 23670,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Paladin, Priest, Warlock
	[120227] = { -- chest
		Items = {
			[QUESTREWARD] = {
				22999, 23834, 23843,
			},
			[RAID_HEROIC] = {
				22999, 23834, 23843,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120228] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23000, 23831, 23840,
			},
			[RAID_HEROIC] = {
				23000, 23831, 23840,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120230] = { -- head
		Items = {
			[QUESTREWARD] = {
				23001, 23832, 23841,
			},
			[RAID_HEROIC] = {
				23001, 23832, 23841,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120229] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23002, 23833, 23842,
			},
			[RAID_HEROIC] = {
				23002, 23833, 23842,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120231] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23003, 23835, 23844,
			},
			[RAID_HEROIC] = {
				23003, 23835, 23844,
			},
		},
		Classes = CLASS_GROUP_5,
	},


	--Normal
	-- warrior, hunter, shaman, monk
	[120222] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23067, 23775, 23362, 23477,
			},
			[RAID_NORMAL] = {
				23067, 23775, 23362, 23477,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120223] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23068, 23776, 23368, 23478,
			},
			[RAID_NORMAL] = {
				23068, 23776, 23368, 23478,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120225] = { -- head
		Items = {
			[QUESTREWARD] = {
				23069, 23777, 23360, 23479,
			},
			[RAID_NORMAL] = {
				23069, 23777, 23360, 23479,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120224] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23070, 23778, 23365, 23480,
			},
			[RAID_NORMAL] = {
				23070, 23778, 23365, 23480,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[120226] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23071, 23779, 23361, 23481,
			},
			[RAID_NORMAL] = {
				23071, 23779, 23361, 23481,
			},
		},
		Classes = CLASS_GROUP_6,
	},


	-- Rogue, Death Knight, Mage, Druid
	[120221] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23129, 23888, 23415, 23647,
			},
			[RAID_NORMAL] = {
				23129, 23888, 23415, 23647,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120217] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23130, 23889, 23412, 23648,
			},
			[RAID_NORMAL] = {
				23130, 23889, 23412, 23648,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120218] = { -- head
		Items = {
			[QUESTREWARD] = {
				23127, 23890, 23413, 23649,
			},
			[RAID_NORMAL] = {
				23127, 23890, 23413, 23649,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120219] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23131, 23893, 23414, 23650,
			},
			[RAID_NORMAL] = {
				23131, 23893, 23414, 23650,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[120220] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23132, 23891, 23416, 23651,
			},
			[RAID_NORMAL] = {
				23132, 23891, 23416, 23651,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Paladin, Priest, Warlock
	[120212] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23007, 23823, 23852,
			},
			[RAID_NORMAL] = {
				23007, 23823, 23852,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120213] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23008, 23820, 23849,
			},
			[RAID_NORMAL] = {
				23008, 23820, 23849,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120215] = { -- head
		Items = {
			[QUESTREWARD] = {
				23009, 23821, 23850,
			},
			[RAID_NORMAL] = {
				23009, 23821, 23850,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120214] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23010, 23822, 23851,
			},
			[RAID_NORMAL] = {
				23010, 23822, 23851,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[120216] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23011, 23819, 23853,
			},
			[RAID_NORMAL] = {
				23011, 23819, 23853,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	-- "Drop Tokens" (I don't think these actually drop, but they're in the dungeon journal)
		-- Paladin, Priest, Warlock
	[119305] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23007, 23823, 23852,
			},
			[RAID_NORMAL] = {
				23007, 23823, 23852,
			},
			[RAID_HEROIC] = {
				22999, 23834, 23843,
			},
			[RAID_MYTHIC] = {
				23219, 24033, 23868,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[119306] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23008, 23820, 23849,
			},
			[RAID_NORMAL] = {
				23008, 23820, 23849,
			},
			[RAID_HEROIC] = {
				23000, 23831, 23840,
			},
			[RAID_MYTHIC] = {
				23220, 24028, 23865,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[119308] = { -- head
		Items = {
			[QUESTREWARD] = {
				23009, 23821, 23850,
			},
			[RAID_NORMAL] = {
				23009, 23821, 23850,
			},
			[RAID_HEROIC] = {
				23001, 23832, 23841,
			},
			[RAID_MYTHIC] = {
				23221, 24029, 23866,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[119307] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23010, 23822, 23851,
			},
			[RAID_NORMAL] = {
				23010, 23822, 23851,
			},
			[RAID_HEROIC] = {
				23002, 23833, 23842,
			},
			[RAID_MYTHIC] = {
				23222, 24030, 23867,
			},
		},
		Classes = CLASS_GROUP_5,
	},
	[119309] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23011, 23819, 23853,
			},
			[RAID_NORMAL] = {
				23011, 23819, 23853,
			},
			[RAID_HEROIC] = {
				23003, 23835, 23844,
			},
			[RAID_MYTHIC] = {
				23223, 24031, 23869,
			},
		},
		Classes = CLASS_GROUP_5,
	},

	-- Warrior, Hunter, Shaman, Monk

	[119318] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23067, 23775, 23362, 23477,
			},
			[RAID_NORMAL] = {
				23067, 23775, 23362, 23477,
			},
			[RAID_HEROIC] = {
				23111, 23767, 23373, 23469,
			},
			[RAID_MYTHIC] = {
				23156, 23912, 23676, 23638,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[119319] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23068, 23776, 23368, 23478,
			},
			[RAID_NORMAL] = {
				23068, 23776, 23368, 23478,
			},
			[RAID_HEROIC] = {
				23112, 23768, 23378, 23470,
			},
			[RAID_MYTHIC] = {
				23157, 23913, 23677, 23470,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[119321] = { -- head
		Items = {
			[QUESTREWARD] = {
				23069, 23777, 23360, 23479,
			},
			[RAID_NORMAL] = {
				23069, 23777, 23360, 23479,
			},
			[RAID_HEROIC] = {
				23113, 23769, 23370, 23471,
			},
			[RAID_MYTHIC] = {
				23151, 23914, 23678, 23471,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[119320] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23070, 23778, 23365, 23480,
			},
			[RAID_NORMAL] = {
				23070, 23778, 23365, 23480,
			},
			[RAID_HEROIC] = {
				23114, 23770, 23375, 23472,
			},
			[RAID_MYTHIC] = {
				23158, 23919, 23472, 23689,
			},
		},
		Classes = CLASS_GROUP_6,
	},
	[119322] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23071, 23779, 23361, 23481,
			},
			[RAID_NORMAL] = {
				23071, 23779, 23361, 23481,
			},
			[RAID_HEROIC] = {
				23115, 23771, 23371, 23473,
			},
			[RAID_MYTHIC] = {
				23152, 23920, 23679, 23473,
			},
		},
		Classes = CLASS_GROUP_6,
	},

	-- Rogue, Death Knight, Mage, Druid
	[119315] = { -- chest
		Items = {
			[QUESTREWARD] = {
				23129, 23888, 23415, 23647,
			},
			[RAID_NORMAL] = {
				23129, 23888, 23415, 23647,
			},
			[RAID_HEROIC] = {
				23138, 23896, 23424, 23666,
			},
			[RAID_MYTHIC] = {
				23487, 24085, 23606, 23663,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[119311] = { -- hand
		Items = {
			[QUESTREWARD] = {
				23130, 23889, 23412, 23648,
			},
			[RAID_NORMAL] = {
				23130, 23889, 23412, 23648,
			},
			[RAID_HEROIC] = {
				23137, 23897, 23421, 23667,
			},
			[RAID_MYTHIC] = {
				23488, 24086, 23603, 23657,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[119312] = { -- head
		Items = {
			[QUESTREWARD] = {
				23127, 23890, 23413, 23649,
			},
			[RAID_NORMAL] = {
				23127, 23890, 23413, 23649,
			},
			[RAID_HEROIC] = {
				23140, 23898, 23422, 23668,
			},
			[RAID_MYTHIC] = {
				23489, 24087, 23604, 23658,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[119313] = { -- leg
		Items = {
			[QUESTREWARD] = {
				23131, 23893, 23414, 23650,
			},
			[RAID_NORMAL] = {
				23131, 23893, 23414, 23650,
			},
			[RAID_HEROIC] = {
				23136, 23900, 23423, 23669,
			},
			[RAID_MYTHIC] = {
				23490, 24088, 23605, 23660,
			},
		},
		Classes = CLASS_GROUP_7,
	},
	[119314] = { -- shoulder
		Items = {
			[QUESTREWARD] = {
				23132, 23891, 23416, 23651,
			},
			[RAID_NORMAL] = {
				23132, 23891, 23416, 23651,
			},
			[RAID_HEROIC] = {
				23135, 23899, 23425, 23670,
			},
			[RAID_MYTHIC] = {
				23491, 24089, 23607, 23661,
			},
		},
		Classes = CLASS_GROUP_7,
	},


	-- Karazhan
	-- helm
	[29760] = { -- paladin, rogue, shaman
		Items = {
			[RAID_FINDER] = {
				7452, 6912, 7441, 6767, 7436, 6803,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[29761] = { -- warrior, priest, druid
		Items = {
			[RAID_FINDER] = {
				7431, 6397, 7446, 6916, 7467, 7054,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[29759] = { -- hunter, mage, warlock
		Items = {
			[RAID_FINDER] = {
				7462, 7148, 7457, 6773, 7414, 6403,
			},
		},
		Classes = CLASS_GROUP_29,
	},
	-- hand
	[29757] = { -- paladin, rogue, shaman
		Items = {
			[RAID_FINDER] = {
				7456, 6911, 7445, 6771, 7440, 6805,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[29758] = { -- warrior, priest, druid
		Items = {
			[RAID_FINDER] = {
				7435, 6400, 7450, 6915, 7471, 7053,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[29756] = { -- hunter, mage, warlock
		Items = {
			[RAID_FINDER] = {
				7466, 7152, 7461, 6775, 7419, 6406,
			},
		},
		Classes = CLASS_GROUP_29,
	},

	-- Gruul's Lair
	-- shoulders
	[29763] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7455, 6914, 7444, 6769, 7439, 6804,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[29764] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7434, 6398, 7449, 6918, 7470, 7056,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[29762] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7465, 7150, 7460, 6772, 7418, 6404,
			},
		},
		Classes = CLASS_GROUP_29,
	},

	-- legs
	[29766] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7454, 6913, 7443, 6770, 7438, 6806,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[29767] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7433, 6399, 7448, 6917, 7469, 7055,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[29765] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7464, 7149, 7459, 6776, 7417, 6405,
			},
		},
		Classes = CLASS_GROUP_29,
	},

	-- Magtheridon's Lair
	-- chest
	[29754] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7453, 6910, 7442, 6768, 7437, 6802,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[29753] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7432, 6396, 7447, 6919, 7468, 7057,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[29755] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7463, 7151, 7458, 6774, 7415, 6402,
			},
		},
		Classes = CLASS_GROUP_29,
	},



	-- Serpentshrine Cavern
	-- hand
	[30239] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7815, 8310, 7825, 8314, 7837, 8318,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[30240] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7810, 7914, 7831, 8322, 7857, 8299,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[30241] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7820, 8295, 7847, 8329, 7851, 8304,
			},
		},
		Classes = CLASS_GROUP_29,
	},

	-- helm
	[30242] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7816, 8313, 7826, 8315, 7838, 8319,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[30243] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7811, 7915, 7832, 8323, 7858, 8300,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[30244] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7821, 8296, 7848, 8328, 7852, 8305,
			},
		},
		Classes = CLASS_GROUP_29,
	},

	-- legs
	[30245] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7817, 8311, 7828, 7742, 7839, 8320,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[30246] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7812, 7916, 7833, 8324, 7859, 8301,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[30247] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7822, 8297, 7849, 8331, 7853, 8306,
			},
		},
		Classes = CLASS_GROUP_29,
	},


	-- The Eye
	-- chest
	[30236] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7814, 8309, 7824, 8316, 7836, 8317,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[30237] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7809, 7913, 7830, 8326, 7856, 8303,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[30238] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7819, 8294, 7845, 8330, 7854, 8308,
			},
		},
		Classes = CLASS_GROUP_29,
	},

	-- shoulders
	[30248] = { -- paladin, rogue, shaman
		Items = {
			[RAID_HEROIC] = {
				7818, 8312, 7829, 7778, 7840, 8321,
			},
		},
		Classes = CLASS_GROUP_27,
	},
	[30249] = { -- warrior, priest, druid
		Items = {
			[RAID_HEROIC] = {
				7813, 7917, 7834, 8325, 7860, 8302,
			},
		},
		Classes = CLASS_GROUP_28,
	},
	[30250] = { -- hunter, mage, warlock
		Items = {
			[RAID_HEROIC] = {
				7823, 8298, 7850, 8327, 7855, 8307,
			},
		},
		Classes = CLASS_GROUP_29,
	},

	-- Battle for Mount Hyjal
	-- hands
	[31092] = { -- paladin, priest, warlock
		Items = {
			[RAID_HEROIC] = {
				8063, 8310, 8102, 8322, 8092, 8304,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[31094] = { -- warrior, hunter, shaman
		Items = {
			[RAID_HEROIC] = {
				8058, 7914, 8069, 8295, 8074, 8318,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[31093] = { -- rogue, mage, druid
		Items = {
			[RAID_HEROIC] = {
				8081, 8314, 8097, 8329, 8086, 8299,
			},
		},
		Classes = CLASS_GROUP_25,
	},

	-- helm
	[31097] = { -- paladin, priest, warlock
		Items = {
			[RAID_HEROIC] = {
				8064, 8313, 8104, 8323, 8093, 8305,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[31095] = { -- warrior, hunter, shaman
		Items = {
			[RAID_HEROIC] = {
				8059, 7915, 8070, 8296, 8076, 8319,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[31096] = { -- rogue, mage, druid
		Items = {
			[RAID_HEROIC] = {
				8082, 8315, 8098, 8328, 8087, 8300,
			},
		},
		Classes = CLASS_GROUP_25,
	},


	-- Black Temple
	-- chest
	[31089] = { -- paladin, priest, warlock
		Items = {
			[RAID_NORMAL] = {
				8065, 8309, 8105, 8326, 8094, 8308,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[31091] = { -- warrior, hunter, shaman
		Items = {
			[RAID_NORMAL] = {
				8060, 7913, 8071, 8294, 8078, 8317,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[31090] = { -- rogue, mage, druid
		Items = {
			[RAID_NORMAL] = {
				8083, 8316, 8099, 8330, 8088, 8303,
			},
		},
		Classes = CLASS_GROUP_25,
	},

	-- legs
	[31098] = { -- paladin, priest, warlock
		Items = {
			[RAID_NORMAL] = {
				8066, 8311, 8106, 8324, 8095, 8306,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[31100] = { -- warrior, hunter, shaman
		Items = {
			[RAID_NORMAL] = {
				8061, 7916, 8072, 8297, 8079, 8320,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[31099] = { -- rogue, mage, druid
		Items = {
			[RAID_NORMAL] = {
				8084, 7742, 8100, 8331, 8089, 8301,
			},
		},
		Classes = CLASS_GROUP_25,
	},

	-- shoulders
	[31101] = { -- paladin, priest, warlock
		Items = {
			[RAID_NORMAL] = {
				8067, 8312, 8107, 8325, 8096, 8307,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[31103] = { -- warrior, hunter, shaman
		Items = {
			[RAID_NORMAL] = {
				8062, 7917, 8073, 8298, 8080, 8321,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[31102] = { -- rogue, mage, druid
		Items = {
			[RAID_NORMAL] = {
				8085, 7778, 8101, 8327, 8091, 8302,
			},
		},
		Classes = CLASS_GROUP_25,
	},

	-- Sunwell
	-- belt
	
	[34853] = { --Paladin, Priest, Warlock
		Items = {
			[RAID_HEROIC] = {
				8975, 8383, 8989, 8805, 8994, 8357,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[34854] = { -- warrior, hunter, shaman
		Items = {
			[RAID_HEROIC] = {
				8996, 8785, 8997, 8793, 8995, 8644,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[34855] = { -- rogue, mage, druid
		Items = {
			[RAID_HEROIC] = {
				9002, 8362, 9001, 8808, 9000, 8795,
			},
		},
		Classes = CLASS_GROUP_25,
	},

	-- boots
	[34856] = { -- paladin, priest, warlock
		Items = {
			[RAID_HEROIC] = {
				9003, 8801, 9004, 8807, 9005, 8799,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[34857] = { -- warrior, hunter, shaman
		Items = {
			[RAID_HEROIC] = {
				9007, 8786, 9008, 8794, 9006, 8804,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[34858] = { -- Rogue, Mage, Druid
		Items = {
			[RAID_HEROIC] = {
				9011, 8802, 9010, 8810, 9009, 8796,
			},
		},
		Classes = CLASS_GROUP_25,
	},

	-- bracers
	[34848] = { -- paladin, priest, warlock
		Items = {
			[RAID_HEROIC] = {
				8956, 8800, 8957, 8806, 8958, 8798,
			},
		},
		Classes = CLASS_GROUP_26,
	},
	[34851] = { -- warrior, hunter, shaman
		Items = {
			[RAID_HEROIC] = {
				8960, 8787, 8961, 8792, 8959, 8803,
			},
		},
		Classes = CLASS_GROUP_30,
	},
	[34852] = { -- Rogue, Mage, Druid
		Items = {
			[RAID_HEROIC] = {
				8964, 8496, 8963, 8809, 8962, 8797,
			},
		},
		Classes = CLASS_GROUP_25,
	},



	-- Undermine

	-- death knight, warlock, demon hunter
	[228807] = { -- head
		Items = {
			[RAID_FINDER] = {
				95444, 96160, 95498,
			},
			[RAID_NORMAL] = {
				95422, 96148, 95508,
			},
			[RAID_HEROIC] = {
				95433, 96136, 95488,
			},
			[RAID_MYTHIC] = {
				95475, 96194, 95536,
			},
			[LegendaryCrafting_5] = {
				95422, 96148, 95508,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[228815] = { -- shoulder
		Items = {
			[RAID_FINDER] = {
				95445, 96161, 95499,
			},
			[RAID_NORMAL] = {
				95423, 96149, 95509,
			},
			[RAID_HEROIC] = {
				95434, 96137, 95489,
			},
			[RAID_MYTHIC] = {
				95476, 96195, 95537,
			},
			[LegendaryCrafting_5] = {
				95423, 96149, 95509,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[228799] = { -- chest
		Items = {
			[RAID_FINDER] = {
				95446, 96162, 95500,
			},
			[RAID_NORMAL] = {
				95424, 96150, 95510,
			},
			[RAID_HEROIC] = {
				95435, 96138, 95490,
			},
			[RAID_MYTHIC] = {
				95468, 96186, 95588,
			},
			[LegendaryCrafting_5] = {
				95424, 96150, 95510,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[228803] = { -- hand
		Items = {
			[RAID_FINDER] = {
				95451, 96167, 95505,
			},
			[RAID_NORMAL] = {
				95429, 96155, 95515,
			},
			[RAID_HEROIC] = {
				95440, 96143, 95495,
			},
			[RAID_MYTHIC] = {
				95473, 96191, 95594,
			},
			[LegendaryCrafting_5] = {
				95429, 96155, 95515,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[228811] = { -- leg
		Items = {
			[RAID_FINDER] = {
				95448, 96164, 95502,
			},
			[RAID_NORMAL] = {
				95426, 96152, 95512,
			},
			[RAID_HEROIC] = {
				95437, 96140, 95492,
			},
			[RAID_MYTHIC] = {
				95470, 96188, 95600,
			},
			[LegendaryCrafting_5] = {
				95426, 96152, 95512,
			},
		},
		Classes = CLASS_GROUP_1,
	},

	-- hunter, mage, druid
	[228808] = { -- head
		Items = {
			[RAID_FINDER] = {
				97767, 96697, 96814,
			},
			[RAID_NORMAL] = {
				97800, 96708, 96802,
			},
			[RAID_HEROIC] = {
				97789, 96649, 96754,
			},
			[RAID_MYTHIC] = {
				97765, 96691, 96776,
			},
			[LegendaryCrafting_5] = {
				97800, 96708, 96802,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[228816] = { -- shoulder
		Items = {
			[RAID_FINDER] = {
				97768, 96693, 96815,
			},
			[RAID_NORMAL] = {
				97801, 96704, 96803,
			},
			[RAID_HEROIC] = {
				97790, 96650, 96755,
			},
			[RAID_MYTHIC] = {
				97766, 96692, 96777,
			},
			[LegendaryCrafting_5] = {
				97801, 96704, 96803,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[228800] = { -- chest
		Items = {
			[RAID_FINDER] = {
				97769, 96694, 96816,
			},
			[RAID_NORMAL] = {
				97802, 96705, 96804,
			},
			[RAID_HEROIC] = {
				97791, 96651, 96756,
			},
			[RAID_MYTHIC] = {
				97758, 96684, 96768,
			},
			[LegendaryCrafting_5] = {
				97802, 96705, 96804,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[228804] = { -- hand
		Items = {
			[RAID_FINDER] = {
				97774, 96695, 96821,
			},
			[RAID_NORMAL] = {
				97807, 96706, 96809,
			},
			[RAID_HEROIC] = {
				97796, 96656, 96761,
			},
			[RAID_MYTHIC] = {
				97763, 96689, 96773,
			},
			[LegendaryCrafting_5] = {
				97807, 96706, 96809,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[228812] = { -- leg
		Items = {
			[RAID_FINDER] = {
				97771, 96700, 96818,
			},
			[RAID_NORMAL] = {
				97804, 96711, 96806,
			},
			[RAID_HEROIC] = {
				97793, 96653, 96758,
			},
			[RAID_MYTHIC] = {
				97760, 96686, 96770,
			},
			[LegendaryCrafting_5] = {
				97804, 96711, 96806,
			},
		},
		Classes = CLASS_GROUP_2,
	},


	-- paladin, priest, shaman
	[228809] = { -- head
		Items = {
			[RAID_FINDER] = {
				97044, 98996, 98303,
			},
			[RAID_NORMAL] = {
				97035, 98985, 98261,
			},
			[RAID_HEROIC] = {
				96991, 98952, 98235,
			},
			[RAID_MYTHIC] = {
				97011, 98950, 98300,
			},
			[LegendaryCrafting_5] = {
				97035, 98985, 98261,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[228817] = { -- shoulder
		Items = {
			[RAID_FINDER] = {
				97045, 98997, 98304,
			},
			[RAID_NORMAL] = {
				97055, 98986, 98262,
			},
			[RAID_HEROIC] = {
				96992, 98953, 98236,
			},
			[RAID_MYTHIC] = {
				97012, 98951, 98301,
			},
			[LegendaryCrafting_5] = {
				97055, 98986, 98262,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[228801] = { -- chest
		Items = {
			[RAID_FINDER] = {
				97046, 98998, 98305,
			},
			[RAID_NORMAL] = {
				97036, 98987, 98263,
			},
			[RAID_HEROIC] = {
				96993, 98954, 98237,
			},
			[RAID_MYTHIC] = {
				97004, 98943, 98292,
			},
			[LegendaryCrafting_5] = {
				97036, 98987, 98263,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[228805] = { -- hand
		Items = {
			[RAID_FINDER] = {
				97051, 99003, 98310,
			},
			[RAID_NORMAL] = {
				97041, 98992, 98269,
			},
			[RAID_HEROIC] = {
				96998, 98959, 98242,
			},
			[RAID_MYTHIC] = {
				97009, 98948, 116474,
			},
			[LegendaryCrafting_5] = {
				97041, 98992, 98269,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[228813] = { -- leg
		Items = {
			[RAID_FINDER] = {
				97048, 99000, 98307,
			},
			[RAID_NORMAL] = {
				97038, 104693, 98265,
			},
			[RAID_HEROIC] = {
				96995, 98956, 98239,
			},
			[RAID_MYTHIC] = {
				97006, 98945, 98294,
			},
			[LegendaryCrafting_5] = {
				97038, 104693, 98265,
			},
		},
		Classes = CLASS_GROUP_3,
	},


	-- warrior, rogue, monk, evoker
	[228810] = { -- head
		Items = {
			[RAID_FINDER] = {
				98728, 94284, 96942, 99477,
			},
			[RAID_NORMAL] = {
				98680, 94334, 96966, 99507,
			},
			[RAID_HEROIC] = {
				98668, 94314, 96906, 99467,
			},
			[RAID_MYTHIC] = {
				98725, 94324, 96939, 99465,
			},
			[LegendaryCrafting_5] = {
				98680, 94334, 96966, 99507,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[228818] = { -- shoulder
		Items = {
			[RAID_FINDER] = {
				98729, 94285, 96943, 99478,
			},
			[RAID_NORMAL] = {
				98681, 94335, 96967, 99508,
			},
			[RAID_HEROIC] = {
				98669, 94315, 96907, 99468,
			},
			[RAID_MYTHIC] = {
				98726, 94333, 96940, 99466
			},
			[LegendaryCrafting_5] = {
				98681, 94335, 96967, 99508,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[228802] = { -- chest
		Items = {
			[RAID_FINDER] = {
				98730, 94286, 96944, 99479,
			},
			[RAID_NORMAL] = {
				98682, 94336, 96968, 99509,
			},
			[RAID_HEROIC] = {
				98670, 94316, 96908, 99469,
			},
			[RAID_MYTHIC] = {
				98718, 94326, 96932, 99459,
			},
			[LegendaryCrafting_5] = {
				98682, 94336, 96968, 99509,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[228806] = { -- hand
		Items = {
			[RAID_FINDER] = {
				98735, 94291, 96949, 99484,
			},
			[RAID_NORMAL] = {
				98687, 94341, 96973, 99514,
			},
			[RAID_HEROIC] = {
				98675, 94321, 96913, 99474,
			},
			[RAID_MYTHIC] = {
				98723, 94331, 96937, 99464,
			},
			[LegendaryCrafting_5] = {
				98687, 94341, 96973, 99514,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[228814] = { -- leg
		Items = {
			[RAID_FINDER] = {
				98732, 94288, 96946, 99481,
			},
			[RAID_NORMAL] = {
				98684, 94338, 96970, 99511,
			},
			[RAID_HEROIC] = {
				98672, 94318, 96910, 99471,
			},
			[RAID_MYTHIC] = {
				98720, 94328, 96934, 99461,
			},
			[LegendaryCrafting_5] = {
				98684, 94338, 96970, 99511,
			},
		},
		Classes = CLASS_GROUP_4,
	},

	-- Manaforge Omega
	--Death Knight, Warlock, Demon Hunter
	[237589] = { -- head
		Items = {
			[RAID_FINDER] = {
				115097, 118459, 118561,
			},
			[RAID_NORMAL] = {
				115141, 118395, 118550,
			},
			[RAID_HEROIC] = {
				115119, 118408, 118572,
			},
			[RAID_MYTHIC] = {
				115139, 118444, 118590,
			},
			[LegendaryCrafting_6] = {
				115141, 118395, 118550,
			},
			[LegendaryCrafting_5] = {
				115141, 118395, 118550,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[237597] = { -- shoulders
		Items = {
			[RAID_FINDER] = {
				115098, 118460, 118562,
			},
			[RAID_NORMAL] = {
				115142, 118396, 118551,
			},
			[RAID_HEROIC] = {
				115120, 118409, 118614,
			},
			[RAID_MYTHIC] = {
				115140, 118445, 118591,
			},
			[LegendaryCrafting_6] = {
				115142, 118396, 118551,
			},
			[LegendaryCrafting_5] = {
				115142, 118396, 118551,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[237581] = { -- chest
		Items = {
			[RAID_FINDER] = {
				115099, 118461, 118563,
			},
			[RAID_NORMAL] = {
				115143, 118397, 118552,
			},
			[RAID_HEROIC] = {
				115121, 118410, 118573,
			},
			[RAID_MYTHIC] = {
				115132, 118435, 118583,
			},
			[LegendaryCrafting_6] = {
				115143, 118397, 118552,
			},
			[LegendaryCrafting_5] = {
				115143, 118397, 118552,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[237585] = { -- hands
		Items = {
			[RAID_FINDER] = {
				115104, 118466, 118568,
			},
			[RAID_NORMAL] = {
				115148, 118402, 118557,
			},
			[RAID_HEROIC] = {
				115126, 118415, 118578,
			},
			[RAID_MYTHIC] = {
				115137, 118441, 118588,
			},
			[LegendaryCrafting_6] = {
				115148, 118402, 118557,
			},
			[LegendaryCrafting_5] = {
				115148, 118402, 118557,
			},
		},
		Classes = CLASS_GROUP_1,
	},
	[237593] = { -- legs
		Items = {
			[RAID_FINDER] = {
				115101, 118463, 118565,
			},
			[RAID_NORMAL] = {
				115145, 118399, 118554,
			},
			[RAID_HEROIC] = {
				115123, 118412, 118575,
			},
			[RAID_MYTHIC] = {
				115134, 118437, 118585,
			},
			[LegendaryCrafting_6] = {
				115145, 118399, 118554,
			},
			[LegendaryCrafting_5] = {
				115145, 118399, 118554,
			},
		},
		Classes = CLASS_GROUP_1,
	},

	--Hunter, Mage, Druid
	[237590] = { -- head
		Items = {
			[RAID_FINDER] = {
				116778, 116918, 118343,
			},
			[RAID_NORMAL] = {
				116723, 116944, 118319,
			},
			[RAID_HEROIC] = {
				116745, 116957, 118381,
			},
			[RAID_MYTHIC] = {
				116776, 116993, 118365,
			},
			[LegendaryCrafting_6] = {
				116723, 116944, 118319,
			},
			[LegendaryCrafting_5] = {
				116723, 116944, 118319,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[237598] = { -- shoulders
		Items = {
			[RAID_FINDER] = {
				116779, 116919, 118344,
			},
			[RAID_NORMAL] = {
				116724, 116945, 118320,
			},
			[RAID_HEROIC] = {
				116746, 116958, 118382,
			},
			[RAID_MYTHIC] = {
				116777, 116994, 118366,
			},
			[LegendaryCrafting_6] = {
				116724, 116945, 118320,
			},
			[LegendaryCrafting_5] = {
				116724, 116945, 118320,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[237582] = { -- chest
		Items = {
			[RAID_FINDER] = {
				116780, 116920, 118345,
			},
			[RAID_NORMAL] = {
				116725, 116946, 118321,
			},
			[RAID_HEROIC] = {
				116747, 116959, 118383,
			},
			[RAID_MYTHIC] = {
				116769, 116985, 118677,
			},
			[LegendaryCrafting_6] = {
				116725, 116946, 118321,
			},
			[LegendaryCrafting_5] = {
				116725, 116946, 118321,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[237586] = { -- hands
		Items = {
			[RAID_FINDER] = {
				116785, 116925, 118350,
			},
			[RAID_NORMAL] = {
				116730, 116951, 118326,
			},
			[RAID_HEROIC] = {
				116752, 116964, 118388,
			},
			[RAID_MYTHIC] = {
				116774, 116990, 118363,
			},
			[LegendaryCrafting_6] = {
				116730, 116951, 118326,
			},
			[LegendaryCrafting_5] = {
				116730, 116951, 118326,
			},
		},
		Classes = CLASS_GROUP_2,
	},
	[237594] = { -- legs
		Items = {
			[RAID_FINDER] = {
				116782, 116922, 118347,
			},
			[RAID_NORMAL] = {
				116727, 116948, 118323,
			},
			[RAID_HEROIC] = {
				116749, 116961, 118385,
			},
			[RAID_MYTHIC] = {
				116771, 116987, 118360,
			},
			[LegendaryCrafting_6] = {
				116727, 116948, 118323,
			},
			[LegendaryCrafting_5] = {
				116727, 116948, 118323,
			},
		},
		Classes = CLASS_GROUP_2,
	},

	-- Paladin, Priest, Shaman
	[237591] = { -- head
		Items = {
			[RAID_FINDER] = {
				115891, 116350, 118528,
			},
			[RAID_NORMAL] = {
				115879, 116338, 118518,
			},
			[RAID_HEROIC] = {
				115915, 116302, 118498,
			},
			[RAID_MYTHIC] = {
				115876, 116300, 118517,
			},
			[LegendaryCrafting_6] = {
				115879, 116338, 118518,
			},
			[LegendaryCrafting_5] = {
				115879, 116338, 118518,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[237599] = { -- shoulders
		Items = {
			[RAID_FINDER] = {
				115892, 116351, 118529,
			},
			[RAID_NORMAL] = {
				115880, 116339, 118519,
			},
			[RAID_HEROIC] = {
				115916, 116303, 118499,
			},
			[RAID_MYTHIC] = {
				115877, 116301, 118508,
			},
			[LegendaryCrafting_6] = {
				115880, 116339, 118519,
			},
			[LegendaryCrafting_5] = {
				115880, 116339, 118519,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[237583] = { -- chest
		Items = {
			[RAID_FINDER] = {
				115893, 116352, 118530,
			},
			[RAID_NORMAL] = {
				115881, 116340, 118520,
			},
			[RAID_HEROIC] = {
				115917, 116304, 118500,
			},
			[RAID_MYTHIC] = {
				115869, 116292, 118510,
			},
			[LegendaryCrafting_6] = {
				115881, 116340, 118520,
			},
			[LegendaryCrafting_5] = {
				115881, 116340, 118520,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[237587] = { -- hands
		Items = {
			[RAID_FINDER] = {
				115898, 116357, 118535,
			},
			[RAID_NORMAL] = {
				115886, 116345, 118525,
			},
			[RAID_HEROIC] = {
				115922, 116309, 118505,
			},
			[RAID_MYTHIC] = {
				115874, 116297, 118515,
			},
			[LegendaryCrafting_6] = {
				115886, 116345, 118525,
			},
			[LegendaryCrafting_5] = {
				115886, 116345, 118525,
			},
		},
		Classes = CLASS_GROUP_3,
	},
	[237595] = { -- legs
		Items = {
			[RAID_FINDER] = {
				115895, 116354, 118532,
			},
			[RAID_NORMAL] = {
				115883, 116342, 118522,
			},
			[RAID_HEROIC] = {
				115919, 116306, 118502,
			},
			[RAID_MYTHIC] = {
				115871, 116294, 118512,
			},
			[LegendaryCrafting_6] = {
				115883, 116342, 118522,
			},
			[LegendaryCrafting_5] = {
				115883, 116342, 118522,
			},
		},
		Classes = CLASS_GROUP_3,
	},

	-- Warrior, Rogue, Monk, Evoker
	[237592] = { -- head
		Items = {
			[RAID_FINDER] = {
				116679, 117783, 117543, 104847,
			},
			[RAID_NORMAL] = {
				116701, 117773, 117531, 104836,
			},
			[RAID_HEROIC] = {
				116712, 117763, 117555, 104825,
			},
			[RAID_MYTHIC] = {
				116699, 117793, 117600, 104878,
			},
			[LegendaryCrafting_6] = {
				116701, 117773, 117531, 104836,
			},
			[LegendaryCrafting_5] = {
				116701, 117773, 117531, 104836,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[237600] = { -- shoulders
		Items = {
			[RAID_FINDER] = {
				116680, 117784, 117544, 104848,
			},
			[RAID_NORMAL] = {
				116702, 117774, 117532, 104837,
			},
			[RAID_HEROIC] = {
				116713, 117764, 117556, 104826,
			},
			[RAID_MYTHIC] = {
				116700, 117802, 117601, 104879,
			},
			[LegendaryCrafting_6] = {
				116702, 117774, 117532, 104837,
			},
			[LegendaryCrafting_5] = {
				116702, 117774, 117532, 104837,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[237584] = { -- chest
		Items = {
			[RAID_FINDER] = {
				116681, 117785, 117545, 104849,
			},
			[RAID_NORMAL] = {
				116703, 117775, 117533, 104838,
			},
			[RAID_HEROIC] = {
				116714, 117765, 117557, 104827,
			},
			[RAID_MYTHIC] = {
				116692, 117795, 117608, 104871,
			},
			[LegendaryCrafting_6] = {
				116703, 117775, 117533, 104838,
			},
			[LegendaryCrafting_5] = {
				116703, 117775, 117533, 104838,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[237588] = { -- hands
		Items = {
			[RAID_FINDER] = {
				116686, 117790, 117550, 104854,
			},
			[RAID_NORMAL] = {
				116708, 117780, 117538, 104843,
			},
			[RAID_HEROIC] = {
				116719, 117770, 117562, 104832,
			},
			[RAID_MYTHIC] = {
				116697, 117800, 117620, 104876,
			},
			[LegendaryCrafting_6] = {
				116708, 117780, 117538, 104843,
			},
			[LegendaryCrafting_5] = {
				116708, 117780, 117538, 104843,
			},
		},
		Classes = CLASS_GROUP_4,
	},
	[237596] = { -- legs
		Items = {
			[RAID_FINDER] = {
				116683, 117787, 117547, 104851,
			},
			[RAID_NORMAL] = {
				116705, 117777, 117535, 104840,
			},
			[RAID_HEROIC] = {
				116716, 117767, 117559, 104829,
			},
			[RAID_MYTHIC] = {
				116694, 117797, 117595, 104873,
			},
			[LegendaryCrafting_6] = {
				116705, 117777, 117535, 104840,
			},
			[LegendaryCrafting_5] = {
				116705, 117777, 117535, 104840,
			},
		},
		Classes = CLASS_GROUP_4,
	},

};