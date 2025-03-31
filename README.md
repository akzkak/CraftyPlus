# CraftyPlus (Classic WoW 1.12 Addon)

![WoW_26-03-25 (6)](https://github.com/user-attachments/assets/2c4451f3-06af-449d-9dc6-f52d3ea80943)

This addon provides a streamlined interface for listing, filtering, and linking your professions.

- Quickly search for recipes or reagents  
- Filter by materials on hand  
- Easily link materials in chat  
- Mark favorite recipes and filter them  
- Streamline your crafting experience  

## Turtle WoW Fix

**Turtle WoW** displays more visible rows in the profession window (e.g., 23), whereas the original addon only accounted for 8. This mismatch caused right-click (to favorite) and left-click (to select) to fail beyond the first few items.  

## Usage

- **Open a profession window** (e.g., Blacksmithing) to see Crafty's search bar and filtering buttons.  
- **Right-click** on a recipe in the list to favorite/unfavorite it.  
- **Hold ALT** to temporarily show all recipes (bypassing your favorites filter).  
- **Use the "Mats" button** to filter by recipes you can craft immediately with on-hand reagents.

## Gem Helper (Turtle WoW Jewelcrafting Only)

The **Gem Helper** button is a special feature for Turtle WoW's Jewelcrafting profession that solves a unique workflow issue:

- In Turtle WoW, Jewelcrafting gems must be activated (right-clicked) before they can be applied in a trade window
- When a trade window is already open, right-clicking a gem in your bags picks it up instead of activating it
- This creates a frustrating situation where you must close the trade, activate the gem, then reopen the trade

![WoW_31-03-25 (2)](https://github.com/user-attachments/assets/3429002e-402e-43cf-9167-19f7fe281bab)

The Gem Helper button will:
- Only appear when you have the Jewelcrafting profession window open
- Find the selected gem in your bags
- Temporarily close the trade window if one is open (with an automatic explanation to your trade partner)
- Activate the gem for you
- Automatically reopen the trade window

**How to use:**
1. Open your Jewelcrafting profession window
2. Select the gem you want to activate
3. Make sure your trade partner is targeted (or in a party with you)
4. Click the "Gem Helper" button
5. The trade window will reopen automatically after the gem is activated

## Credits

- **Original Author**: [shirsig](https://github.com/shirsig/crafty)  
  - The original Crafty was designed for 1.12 (Vanilla) and has been adapted for Turtle WoW.  