# Tip Tracker

Tip Tracker is a SwiftUI-based iOS application to help users track their work hours and tip earnings. The app provides detailed record-keeping, trends analysis, and a calendar view that highlights days with entries, making it easier to monitor your earnings over time.

## Features

- **Record Tracking:**  
  Log daily work records including hours worked and tips received.

- **Trends Analysis:**  
  View charts and summary metrics that display overall, daily, weekly, and monthly earnings trends.

- **Calendar View:**  
  A calendar marks days with records with a dot. Tap a day to view metrics and quickly edit records.

- **Settings:**  
  Customize settings such as your hourly wage & week start day.

## Requirements

- iOS 16 or later  
- Xcode 14 or later

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/t-trent/tip-tracker-ios
   ```
2. Open `Tip Tracker.xcodeproj` in Xcode.
3. Build and run the project on the iOS Simulator or your device.

## Usage

- **Home (Records):**  
  Add, edit, or delete work records. Your records are saved locally using UserDefaults.

  ![Home](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/Home.png)
  ![Add Record](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/Add%20Record.png)
  ![Edit Record](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/Edit%20Record.png)

- **Trends:**  
  Analyze your earnings with various chart views and summary statistics.  
  Select different groupings (Week, Month, Year) and swipe through time increments to see different trends. 
  
  ![Trends Month](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/Trends%20Month.png)

- **Calendar:**  
  Browse a full-screen calendar that highlights days with recorded entries.  
  Tap a day to view metrics and tap the metrics view to edit a record.
  
  ![Calendar](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/Calendar.png)

- **Settings:**  
  Adjust your hourly wage and other settings to personalize the app's calculations and appearance.
  
  ![Settings](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/Settings.png)
