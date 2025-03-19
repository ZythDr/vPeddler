# vPeddler - Peddler for Vanilla WoW 1.12

A relatively sophisticated junk seller addon that focuses on Qaulity-of-Life features and usage.

## Features

- **Auto-Sell:** Automatically sells any flagged items when visiting vendors
- **Visual Indicators:** Marks auto-sell items in your bags with customizable coin icons
- **Manual Item Flagging:** Right-click with modifier key to manually add/remove any item in your inventory to your auto-sell list
- **Auto-flag Gray Items:** By default, vPeddler will automatically flag any gray items in your inventory
> - **Full Quality-Based Filters:** Select which item quality levels (Poor, Common, Uncommon, etc.) should be automatically sold  
> <sup>WIP, not yet implemented, may come as a separate plugin for vPeddler instead</sup>

### Automatic Repairs
- **Auto-Repair:** Automatically repairs all your equipment when visiting a vendor  
- **Repair Cost Reports:** Shows the cost of repairs in chat  

## Usage

1. **Mark Items for Auto-Sell:** Hold your chosen modifier key (Alt by default) and right-click any item in your bags to toggle it as vendor trash
2. **Auto-Sell Behavior:** When visiting vendors, all marked items ~~and items matching your quality filters~~ (wip) will be sold automatically

### Customization
- **Icon Customization:**
  - Size (10-40 pixels)
  - Position (5 options: Top-Left, Top-Right, Center, Bottom-Left, Bottom-Right)
  - Transparency/Alpha level
  - Icon style (native Gold Coins icon or custom Peddler icon)
  - Optional outlined icons (only for Peddler icon) for better visibility

- **Interaction Options:**
  - Customizable modifier (Alt, Ctrl, Shift) for item flagging
  - Verbose mode showing what was added or removed from auto-sell list
>  - ~~Option for manual sell button instead of automatic selling~~  
> WIP

## Addon Compatibility  
- [x] Compatible with default bags  
- [x] Compatible with Bagshui  
- [x] Compatible with Bagnon  
- [x] Compatible with EngBags  
- [x] Compatible with pfUI bags  
- [x] Compatible with SUCC-bag  
- [x] Compatible with Turtle-Dragonflight/tDF UI  

## Commands

- `/vp` or `/vpeddler` - Toggle options panel (contains all relevant options in a user-friendly GUI)
- `/vp reset` - Reset all settings to defaults
- `/vp resetfilters` - Clear all manually flagged items
- `/vp help` - Show help text

### To-Do:
- [ ] Make the addon truly modular by breaking modules out into separate addons.
- [ ] Add support for items that cannot be sold to vendors (Delete unwanted items at vendor)
- [ ] Implement a manual sell button for paranoid players
- [ ] Create a separate plugin to add remaining features found in the original Peddler addon

---
Created by Peachoo @ Nordanaar - Turtle WoW 
> Actually made using AI Chatbots, primarily Claude 3.7 through Github Copilot

For issues and feature requests, please open an issue on GitHub and I'll try my best to add/fix things.
