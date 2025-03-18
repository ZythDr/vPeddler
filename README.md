# vPeddler - Peddler for Vanilla WoW 1.12

A relatively light-weight and sophisticated junk seller addon that focuses on Qaulity-of-Life features and usage.

## Features

### Automatically sell any marked items
- **Auto-Sell:** Automatically sells designated "junk" items when visiting vendors
- **Visual Indicators:** Marks vendor trash items in your bags with customizable coin icons
- **Manual Item Flagging:** Right-click with modifier key to manually add/remove specific items to your auto-sell list
> - ~~**Quality-Based Filters:** Select which item quality levels (Poor, Common, Uncommon, etc.) should be automatically sold~~  
> <sup>WIP, not yet implemented, may come as a separate plugin for vPeddler instead</sup>

> ### Automatic Repairs
> - ~~**Auto-Repair:** Automatically repairs all your equipment when visiting a vendor~~ WIP
> - ~~**Repair Cost Reports:** Shows the cost of repairs in chat~~ WIP

### Customizable
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

### Addon Compatibility  
- [x] Compatible with default bags  
- [x] Compatible with Bagshui  
- [x] Compatible with Bagnon  
- [x] Compatible with EngBags  
- [x] Compatible with pfUI bags  
- [] Compatible with SUCC-bag  
- [] Compatible with Dragonflight UI

## Usage

1. **Mark Items for Auto-Sell:** Hold your chosen modifier key (Alt by default) and right-click any item in your bags to toggle it as vendor trash
2. **Auto-Sell Behavior:** When visiting vendors, all marked items ~~and items matching your quality filters~~ (wip) will be sold automatically

## Commands

- `/vp` or `/vpeddler` - Toggle options panel (contains all relevant options in a user-friendly GUI)
- `/vp reset` - Reset all settings to defaults
- `/vp resetfilters` - Clear all manually flagged items
- `/vp help` - Show help text

---
Created by Peachoo @ Nordanaar - Turtle WoW 
> Actually made using AI Chatbots, primarily Claude 3.7

For issues and feature requests, please open an issue on GitHub and I'll try my best to add/fix things.
