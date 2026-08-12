// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AonL10nEn extends AonL10n {
  AonL10nEn([String locale = 'en']) : super(locale);

  @override
  String get eventName => 'Astronomy Open Night';

  @override
  String get tabHome => 'Home';

  @override
  String get tabProgram => 'Program';

  @override
  String get tabMyNight => 'Night';

  @override
  String get tabMap => 'Map';

  @override
  String get tabInfo => 'Info';

  @override
  String get myNight => 'My Night';

  @override
  String get myNightEmptyTitle => 'Your night is empty';

  @override
  String get myNightEmptyBody =>
      'Tap the star on any activity to plan your night. We’ll line everything up in time order and tell you where to go.';

  @override
  String myNightNext(String planName) {
    return 'Next in $planName';
  }

  @override
  String myNightSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities saved',
      one: '1 activity saved',
    );
    return '$_temp0';
  }

  @override
  String myNightSessionOf(int index, int total) {
    return 'Session $index of $total';
  }

  @override
  String myNightClearTitle(String planName) {
    return 'Clear $planName?';
  }

  @override
  String get myNightClearBody =>
      'This removes every saved activity. It can’t be undone.';

  @override
  String get myNightAllFinished =>
      'Everything you saved has finished. What a night.';

  @override
  String get myNightConflictBanner =>
      'Some of your saved activities run at the same time. They’re flagged below — most run more than once, so check for another session.';

  @override
  String myNightConflictOverlaps(String titles) {
    return 'Overlaps $titles';
  }

  @override
  String get myNightLoadFailedTitle => 'Couldn’t open your saved plan';

  @override
  String get myNightLoadFailedBody =>
      'Your saved activities are stored on this device. Try again in a moment.';

  @override
  String get timingHappeningNow => 'Happening now';

  @override
  String get timingStartingSoon => 'Starting soon';

  @override
  String get timingLaterTonight => 'Later tonight';

  @override
  String get timingFinished => 'Finished';

  @override
  String get timingOpenAllEvening => 'Open all evening';

  @override
  String timingStartingWithin(int minutes) {
    return 'In the next $minutes minutes';
  }

  @override
  String get phaseTonight => 'Tonight';

  @override
  String get phaseStartsSoon => 'Starts soon';

  @override
  String get phaseHappeningNow => 'Happening now';

  @override
  String get phaseEndingSoon => 'Ending soon';

  @override
  String get phaseEnded => 'This event has finished';

  @override
  String get homeUpNext => 'Up next';

  @override
  String get homeNothingRightNow =>
      'Nothing running this minute — check what’s next.';

  @override
  String homeSeeWholeEvent(String period) {
    return 'See the whole $period';
  }

  @override
  String get homeOpenMapTitle => 'Open the campus map';

  @override
  String get homeOpenMapBody =>
      'Venues, toilets, first aid — and walking directions from the car parks';

  @override
  String get homeOpenMapBodyNoWayfinding =>
      'Venues, toilets, first aid and parking';

  @override
  String get homeQuickAccessTitle => 'Find your way to';

  @override
  String get homeGoodToKnow => 'Good to know';

  @override
  String get homeImageCredit => 'Image credit';

  @override
  String get quickAccessTelescopes => 'Telescopes';

  @override
  String get quickAccessPlanetariums => 'Planetariums';

  @override
  String get quickAccessTalks => 'Talks';

  @override
  String get quickAccessKids => 'Kids’ activities';

  @override
  String get quickAccessFood => 'Food and drink';

  @override
  String get quickAccessToilets => 'Toilets';

  @override
  String get quickAccessFirstAid => 'First aid';

  @override
  String get quickAccessParking => 'Parking';

  @override
  String get quickAccessWalkingRoutes => 'Walking routes';

  @override
  String get programTonight => 'Tonight';

  @override
  String get programSections => 'Sections';

  @override
  String get programSearchHint => 'Search talks, activities, presenters';

  @override
  String programItemCount(int count) {
    return '$count items in the program';
  }

  @override
  String programFilteredCount(int shown, int total) {
    return '$shown of $total shown';
  }

  @override
  String get programNoMatchTitle => 'Nothing matches';

  @override
  String get programNoMatchBody =>
      'Try removing a filter or searching for something else.';

  @override
  String get programClearFilters => 'Clear filters';

  @override
  String get programPreBookingRequired => 'Pre-booking required';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaved => 'Saved';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionWalkThere => 'Walk there';

  @override
  String get actionShowOnMap => 'Show on map';

  @override
  String get actionBrowseProgram => 'Browse the program';

  @override
  String get actionRemoveFromPlan => 'Remove from plan';

  @override
  String get actionBack => 'Back';

  @override
  String a11ySaveToPlan(String title, String planName) {
    return 'Save $title to $planName';
  }

  @override
  String a11yRemoveFromPlan(String title, String planName) {
    return 'Remove $title from $planName';
  }

  @override
  String snackSavedTo(String planName) {
    return 'Saved to $planName';
  }

  @override
  String snackRemovedFrom(String planName) {
    return 'Removed from $planName';
  }

  @override
  String get mapTitle => 'Map';

  @override
  String get mapWalkingDirections => 'Walking directions';

  @override
  String get mapLookInside360 => 'Look inside in 360°';

  @override
  String get mapOnHereTonight => 'On here tonight';

  @override
  String get mapAttribution => '© OpenStreetMap contributors';

  @override
  String get mapRecentre => 'Recentre';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get panorama360Unavailable =>
      '3D view is not available for this location.';

  @override
  String get panorama360Loading => 'Loading the 360° view…';

  @override
  String get panorama360Title => '360° preview';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSystem => 'Follow my phone';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsAppearanceDarkHint =>
      'Recommended — kinder to your night vision at the event';

  @override
  String get settingsMotion => 'Motion';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsReduceMotionBody =>
      'Turns off the tab bar and glass animations. Your phone’s own reduce-motion setting is always respected too.';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsTextSizeTitle => 'Set text size on your phone';

  @override
  String settingsTextSizeBody(int percent) {
    return 'This app follows your device text size, up to $percent% — every screen is tested at that size. Change it in your phone’s display or accessibility settings.';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow my phone';

  @override
  String settingsAbout(String eventName) {
    return 'About $eventName';
  }

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacyTitle => 'Nothing leaves your phone';

  @override
  String get settingsPrivacyBody =>
      'There is no account and no sign-in. Your saved activities are stored on this device only. The app collects no analytics and tracks no location.\n\nThe only thing it fetches from the internet is map imagery.';

  @override
  String get settingsCredits => 'Credits';

  @override
  String get settingsCreditsHeroImage => 'Hero image';

  @override
  String get settingsCreditsEventMaterials => 'Event materials';

  @override
  String get settingsCreditsMapData => 'Map data';

  @override
  String get settingsUnavailableTitle => 'Settings unavailable';

  @override
  String get settingsUnavailableBody =>
      'Your preferences couldn’t be opened on this device. The app still works — it just won’t remember this choice.';

  @override
  String get infoTitle => 'Useful information';

  @override
  String get infoLocationToBeConfirmed => 'Location to be confirmed';

  @override
  String get infoDetailToBeConfirmed => 'This detail is still to be confirmed.';

  @override
  String get eventNotFoundTitle => 'We can’t find that activity';

  @override
  String get eventNotFoundBody =>
      'It may have been changed or removed from the program since this link was shared.';

  @override
  String get wayfindingTitle => 'Walking directions';

  @override
  String get wayfindingStartingFrom => 'Starting from';

  @override
  String get wayfindingGoingTo => 'Going to';

  @override
  String get wayfindingPickTitle => 'Pick a start and a destination';

  @override
  String get wayfindingPickBody =>
      'Choose where you parked and where you’re heading, and we’ll give you written directions for walking it in the dark.';

  @override
  String get wayfindingNoRouteTitle => 'No directions for that pair yet';

  @override
  String get wayfindingNoRouteBody =>
      'We don’t have a written route between those two points. Try the Central Courtyard as a staging point — most routes run through it — or ask at an information point.';

  @override
  String get wayfindingDirections => 'Directions';

  @override
  String get wayfindingStraightLineNote =>
      'Straight line shown — this is the general direction, not the exact path. Follow the written directions below.';

  @override
  String get wayfindingDraftWarning =>
      'These directions are a draft and have not yet been walked and verified on campus at night. Follow event signage and marshals if they differ.';

  @override
  String wayfindingAboutMinutes(int minutes) {
    return 'About $minutes min';
  }

  @override
  String wayfindingApproxMetres(int metres) {
    return '~$metres m';
  }

  @override
  String get wayfindingStepFreeUnknown =>
      'Step-free access along this route has not been confirmed yet. Ask at an information point if you need a step-free path.';

  @override
  String get locateShow => 'Show my location';

  @override
  String get locateFollow => 'Follow my location';

  @override
  String get locateStopFollowing => 'Stop following my location';

  @override
  String get locateLowAccuracy => 'Location accuracy is low';

  @override
  String get locateUnavailable => 'Location unavailable';

  @override
  String get locateServiceOff => 'Turn on Location Services';

  @override
  String get mapLowAccuracy => 'Location accuracy is low';

  @override
  String mapOffCampus(String km) {
    return 'You\'re about $km km from campus';
  }
}
