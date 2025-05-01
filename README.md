# Tip Tracker

Tip Tracker is a SwiftUI-based iOS application to help users track their work hours and tip earnings. The app provides detailed record-keeping, trends analysis, and a calendar view that highlights days with entries, making it easier to monitor your earnings over time.

## Features

- **Record Tracking:**  
  Log daily work records including hours worked and tips received.

- **Trends Analysis:**  
  View charts and summary metrics that display overall, daily, weekly, and monthly earnings trends.

- **Calendar View:**  
  A calendar marks days with records with a dot. Tap a day to view aggregated metrics and quickly edit records.

- **Settings:**  
  Customize settings such as your hourly wage, currency & locale, and other preferences.

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

  ![ContentView](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/content-dark.png)

- **Trends:**  
  Analyze your earnings with various chart views and summary statistics.  
  Select different groupings (Week, Month, Year) and swipe through time increments to see different trends.
  
  ![TrendsView](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/trends-dark.png)

- **Calendar:**  
  Browse a full-screen calendar that highlights days with recorded entries.  
  Tap a day to view metrics and tap the metrics view to edit a record.
  
  ![CalendarView](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/calendar-dark.png)

- **Settings:**  
  Adjust your hourly wage and other settings to personalize the app's calculations and appearance.
  
  ![SettingsView](https://github.com/t-trent/tip-tracker-ios/blob/main/Tip%20Tracker/Preview%20Content/Screenshots/settings-dark.png)

## Architecture

Tip Tracker uses a shared `RecordsStore` to manage work records across the app. This ensures that changes in one view (e.g., adding a record in the Home tab) are immediately reflected in the Trends, Calendar, and Settings views.
