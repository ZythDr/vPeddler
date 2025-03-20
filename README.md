# vPeddler - Peddler for Vanilla WoW 1.12

A relatively sophisticated junk seller addon that focuses on Qaulity-of-Life features and ease of use.

## Usage

1. **Mark Items for Auto-Sell:** Hold your chosen modifier key (Alt by default) and right-click any item in your bags to toggle it as vendor trash
2. **Auto-Sell Behavior:** When visiting vendors, all marked items ~~and items matching your quality filters~~ (wip) will be sold automatically

## Features 
<img src="https://github.com/user-attachments/assets/11d22488-e91b-46e9-9f8d-0b0bdaf89215" float="right" align="right" width="220" >  

- **Auto-Sell:** Automatically sells any flagged items when visiting vendors
- **Visual Indicators:** Displays Auto-Sell items with coin icon markers
- **Manual Item Flagging:** Right-click with modifier key to manually  
add/remove any item in your inventory to your auto-sell list
- **Auto-flag Gray Items:** Automatically add gray items to auto-sell list
> - **Full Quality-Based Filters:** Select which item quality levels  
(Poor, Common, Uncommon, etc.) should be automatically sold  
> <sup>WIP, not yet implemented, may come as a separate plugin for vPeddler instead</sup>

### Automatic Repairs
- **Auto-Repair:** Automatically repairs all your equipment when visiting a vendor  
- **Repair Cost Reports:** Shows the cost of repairs in chat  

**Customization**
 <img src="https://github.com/user-attachments/assets/6437e075-2128-4e7b-99cf-29b59f44b3ee" float="right" align="right" width="220"> 

- **Icon Customization:**
  - Size (10-40 pixels)
  - Position (TopLeft, TopRight, Center, BottomLeft, BottomRight)
  - Transparency/Alpha level
  - Icon style (native Gold Coins icon or custom Peddler icon)
  - Optional outlined icons (only for Peddler icon) for better visibility

- **Interaction Options:**
  - Customizable modifier (Alt, Ctrl, Shift) for item flagging
  - Verbose mode showing what was added or removed from auto-sell list  
>  - ~~Option for manual sell button instead of automatic selling~~  
> WIP
<img src="https://github.com/user-attachments/assets/89996115-56d0-4bca-8601-caf5f6068899" float="right" align="right" width="310"> 

**Addon Compatibility**  
- [x] Blizzard bags  
- [x] Bagshui (req ctrl/shift modifier, change in /vp)
- [x] Bagnon  
- [x] EngBags  
- [x] pfUI bags  
- [x] SUCC-bag  
- [x] Turtle-Dragonflight/tDF UI  

**Commands**

- `/vp` or `/vpeddler` - Options Panel (user-friendly GUI)
- `/vp reset` - Reset all settings to defaults
- `/vp resetfilters` - Clear all manually flagged items
- `/vp help` - Show help text

### To-Do:
- [ ] Make the addon truly modular by breaking modules out into separate addons
- [ ] Add support for items that cannot be sold to vendors (Delete unwanted items at vendor)
- [ ] Implement a manual sell button for paranoid players
- [ ] Create a separate plugin to add remaining features found in the original Peddler addon

---
Created by Peachoo @ Nordanaar - Turtle WoW 
> Actually made using AI Chatbots, primarily Claude 3.7 through Github Copilot

For issues and feature requests, please open an issue on GitHub and I'll try my best to add/fix things.
