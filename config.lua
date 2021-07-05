local addonName, addon = ...

-- Create options UI
local function updateLabelText()
    local linkColor, whichStyle = addonConfig["LinkColor"], addonConfig["WhichStyle"];
    local normalLinkIcon = "";
    if whichStyle == "blizzard" then
        normalLinkIcon = CreateAtlasMarkup("Waypoint-MapPin-ChatIcon", 13, 13);
    end
    local text = "Example link: |cff" .. linkColor .. "|Hgarrmission:TomPoints: |h[" .. normalLinkIcon .. "23.45 45.22]|h|r";
    text = text .. "|n|nIf you see a link with an " .. CreateAtlasMarkup("warlockportalalliance", 15, 15) .. " icon at the beginning, that means the waypoint is in a different zone.";
    text = text .. "|n|nExample: |cff" .. linkColor .. "|Hgarrmission:TomPoints: |h[" .. CreateAtlasMarkup("warlockportalalliance", 15, 15) .. " 23.45 45.22]|h|r";
    TomPoints_infoLabel:SetText(text);
end

local function DropDown_OnClick(self, arg1, arg2, checked)
    if arg1 == 1 then
        addonConfig["WhichStyle"] = self.value;
        addonConfig["LinkColor"] = "149bfd";
    elseif arg1 == 2 then
        addonConfig["WhichStyle"] = self.value;
        addonConfig["LinkColor"] = "ffff00";
    else
        addonConfig["WhichStyle"] = "tompoints";
        addonConfig["LinkColor"] = "149bfd";
    end
    updateLabelText();
    UIDropDownMenu_SetSelectedValue(TomPoints_StyleDropDown, addonConfig["WhichStyle"]);
end

local uniquealyzer = 0;
local function createCheckbutton(parent, x_loc, y_loc, displayname)
  uniquealyzer = uniquealyzer + 1;

  local checkbutton = CreateFrame("CheckButton", "TomPoints_cb" .. uniquealyzer, parent, "ChatConfigCheckButtonTemplate");
  checkbutton:SetPoint("TOPLEFT", x_loc, y_loc);
  getglobal(checkbutton:GetName() .. 'Text'):SetText(displayname);

  return checkbutton;
end

-- Create the Blizzard addon option frame
local panel = CreateFrame("Frame", "TomPointsBlizzOptions", InterfaceOptionsFramePanelContainer);
panel:RegisterEvent("ADDON_LOADED");
panel:Hide()

-- Handle the events as they happen
panel:SetScript("OnShow", function(panel)
  local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
  fs:SetPoint("TOPLEFT", 10, -15);
  fs:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 10, -45);
  fs:SetJustifyH("LEFT");
  fs:SetJustifyV("TOP");
  fs:SetText("TomPoints");
  -- Create option for always creating a map pin when clicking a link
  local cb1 = createCheckbutton(panel, 10, -45, "Always create a Map Pin when clicking a waypoint link");
  cb1.tooltip = "If you have TomTom, this will also create a Map Pin at the location";
  cb1:SetScript("OnClick",
     function(self, button, down)
      addonConfig["AlwaysCreateMapPin"] = self:GetChecked();
     end
  );
  
  -- Create option for sharing Map Pins instead of raw coordinates
  local cb2 = createCheckbutton(panel, 10, -85, "Share Map Pin links when linking waypoints (shift+click them with chat box active)");
  cb2.tooltip = "If this is unchecked, waypoints will be shared as their raw coordinates";
  cb2:SetScript("OnClick",
     function(self, button, down)
      addonConfig["ShareAsPin"] = self:GetChecked();
     end
  );
  
  -- Create option for replacing all map pin links with TomPoints links
  local cb3 = createCheckbutton(panel, 10, -105, "Replace Blizzard Map Pin links with TomPoints links");
  cb3.tooltip = "This allows pin links to be shareable from chat instead of the map";
  cb3:SetScript("OnClick",
     function(self, button, down)
      addonConfig["ReplaceBlizzardLinks"] = self:GetChecked();
     end
  );
  
  -- Create an option to activate map pins 
  local cb4 = createCheckbutton(panel, 10, -65, "Activate Map Pins automatically if they are created by TomPoints");
  cb4.tooltip = "This does nothing if TomPoints is not creating Map Pins";
  cb4:SetScript("OnClick",
     function(self, button, down)
      addonConfig["ActivateMapPin"] = self:GetChecked();
     end
  );
  
  -- Create label to show how the links appear
  local infoLabel = panel:CreateFontString("TomPoints_infoLabel", "OVERLAY", "GameFontNormalSmall");
  infoLabel:SetPoint("TOPLEFT", 35, -125);
  infoLabel:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 35, -185);
  infoLabel:SetJustifyH("LEFT");
  infoLabel:SetJustifyV("TOP");
  
  -- Create a style chooser
  local dropDown = CreateFrame("Frame", "TomPoints_StyleDropDown", panel, "UIDropDownMenuTemplate")
  dropDown:SetPoint("TOPLEFT", 10, -205);
  dropDown.initialize = function()
    local info = UIDropDownMenu_CreateInfo();
    local whichStyle = addonConfig["WhichStyle"];
    info.func = DropDown_OnClick
    info.text, info.arg1, info.checked = "TomPoints Style", 1, whichStyle == "tompoints";
    info.value = "tompoints";
    
    UIDropDownMenu_AddButton(info);
    info.text, info.arg1, info.checked = "Blizzard Map Pin Style", 2, whichStyle == "blizzard";
    info.value = "blizzard";
    UIDropDownMenu_AddButton(info);
    if whichStyle == "tompoints" then
        UIDropDownMenu_SetText(TomPoints_StyleDropDown, "TomPoints Style");
    elseif whichStyle == "blizzard" then
        UIDropDownMenu_SetText(TomPoints_StyleDropDown, "Blizzard Map Pin Style");
    end
  end
  if addonConfig["WhichStyle"] == "tompoints" then
    TomPoints_StyleDropDownText:SetText("TomPoints Style");
  elseif addonConfig["WhichStyle"] == "blizzard" then
    TomPoints_StyleDropDownText:SetText("Blizzard Map Pin Style");
  else
    TomPoints_StyleDropDownText:SetText("Link Style");
  end
  UIDropDownMenu_SetWidth(dropDown, 200);
  TomPoints_cb1:SetChecked(addonConfig["AlwaysCreateMapPin"]);
  TomPoints_cb2:SetChecked(addonConfig["ShareAsPin"]);
  TomPoints_cb3:SetChecked(addonConfig["ReplaceBlizzardLinks"]);
  TomPoints_cb4:SetChecked(addonConfig["ActivateMapPin"]);
  --UIDropDownMenu_Initialize(TomPoints_StyleDropDown, DropDown_MenuInit);
  updateLabelText();
  panel:SetScript("OnShow", nil);
end)
panel.name = "TomPoints";
InterfaceOptions_AddCategory(panel);
