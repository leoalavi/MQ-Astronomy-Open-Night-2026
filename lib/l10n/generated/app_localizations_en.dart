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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items in the program',
      one: '1 item in the program',
    );
    return '$_temp0';
  }

  @override
  String programFilteredCount(int shown, int total) {
    final intl.NumberFormat shownNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String shownString = shownNumberFormat.format(shown);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$shownString of $totalString shown';
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
  String get mapAttributionCampus => 'Campus map: Macquarie University';

  @override
  String get mapRecentre => 'Recentre';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapSearchTitle => 'Find a place';

  @override
  String get mapSearchHint => 'Search buildings and venues';

  @override
  String get mapSearchTooltip => 'Search';

  @override
  String mapSearchEmpty(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get mapFavoritesTitle => 'Favourites';

  @override
  String get mapFavoritesTooltip => 'Favourites';

  @override
  String get mapFavoritesEmpty => 'No favourites yet';

  @override
  String get mapFavoritesLoading => 'Loading…';

  @override
  String get mapFavoriteUnavailable => 'Unavailable';

  @override
  String get mapFavoriteAdd => 'Add to favourites';

  @override
  String get mapFavoriteRemove => 'Remove from favourites';

  @override
  String mapBuildingGridRef(String ref) {
    return 'Grid $ref';
  }

  @override
  String get mapCatAcademic => 'Academic';

  @override
  String get mapCatServices => 'Services';

  @override
  String get mapCatHealth => 'Health';

  @override
  String get mapCatFood => 'Food & drink';

  @override
  String get mapCatSports => 'Sports';

  @override
  String get mapCatVenue => 'Venue';

  @override
  String get mapCatResearch => 'Research';

  @override
  String get mapCatResidential => 'Residential';

  @override
  String get mapCatParking => 'Parking';

  @override
  String get mapCatTransport => 'Transport';

  @override
  String get mapCatSmoking => 'Smoking area';

  @override
  String get mapCatTeaching => 'Teaching';

  @override
  String get mapCatOther => 'Other';

  @override
  String get panorama360Unavailable =>
      '3D view is not available for this location.';

  @override
  String get panorama360Loading => 'Loading the 360° view…';

  @override
  String get panorama360Title => '360° preview';

  @override
  String get panoramaTapToExplore => 'Tap to explore in 360°';

  @override
  String panoramaVenueWithMapLetter(String letter, String name) {
    return '$letter · $name';
  }

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
  String get settingsLanguageSystem => 'Match my device';

  @override
  String settingsAbout(String eventName) {
    return 'About $eventName';
  }

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacyTitle => 'What this app shares';

  @override
  String get settingsPrivacyBody =>
      'There is no account and no sign-in. Your passport stamps, favourites and saved plan stay on this device. The app collects no analytics.\n\nThe camera is used only to read a QR code, and the image is never stored or sent anywhere.\n\nYour location is used on this device to show where you are on the campus map. It is sent to Google only when you ask for walking directions — and only after you agree.\n\nWayfinding draws its route on a Google map. Loading any Google map sends Google the map request plus the technical request and device information it needs to serve it — but not your location.';

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

  @override
  String get mapLocatingOnCampus => 'Locating you on the campus map…';

  @override
  String get pointMeTitle => 'Point me there';

  @override
  String pointMeDistanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String pointMeDistanceKm(String km) {
    return '$km km';
  }

  @override
  String get pointMeFindingNorth => 'Finding north…';

  @override
  String get pointMeNearby => 'You\'re basically there';

  @override
  String get pointMeNoCompass =>
      'The live arrow needs a phone with a compass sensor. Here\'s the direction and distance.';

  @override
  String get pointMeImprovingAccuracy =>
      'Your location is a bit rough right now — here\'s the rough direction. It\'ll sharpen as GPS settles.';

  @override
  String get pointMeNeedsLocation => 'Turn on location to point the way';

  @override
  String get pointMeUnknownPlace => 'We can\'t find that place';

  @override
  String pointMeBearingSentence(
    String venue,
    String distance,
    String cardinal,
  ) {
    return '$venue is about $distance $cardinal of you';
  }

  @override
  String pointMeA11yDirection(String venue, String side, String distance) {
    return '$venue is $side, $distance away';
  }

  @override
  String get sideAhead => 'ahead of you';

  @override
  String get sideBehind => 'behind you';

  @override
  String get sideLeft => 'to your left';

  @override
  String get sideRight => 'to your right';

  @override
  String get cardinalN => 'north';

  @override
  String get cardinalNE => 'north-east';

  @override
  String get cardinalE => 'east';

  @override
  String get cardinalSE => 'south-east';

  @override
  String get cardinalS => 'south';

  @override
  String get cardinalSW => 'south-west';

  @override
  String get cardinalW => 'west';

  @override
  String get cardinalNW => 'north-west';

  @override
  String get mapNavGoogle => 'Navigate with Google Maps';

  @override
  String get mapNavOpenExternal => 'Open in Google Maps';

  @override
  String get mapNavOpenExternalFailed => 'Couldn\'t open Google Maps.';

  @override
  String get mapPlaceListOnly => 'Details only — not shown on the map';

  @override
  String mapNavDistanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String mapNavDistanceKm(String km) {
    return '$km km';
  }

  @override
  String mapNavEtaMin(int mins) {
    return '$mins min';
  }

  @override
  String mapNavEtaHourMin(int hours, int mins) {
    return '$hours hr $mins min';
  }

  @override
  String get mapNavNoRoute => 'No walking route found to here.';

  @override
  String get mapNavOffline => 'You\'re offline — can\'t fetch the route.';

  @override
  String get mapNavError => 'Couldn\'t load the route. Please try again.';

  @override
  String get mapNavNeedLocation =>
      'Turn on location to get walking directions.';

  @override
  String get mapNavUnavailable =>
      'Google navigation isn\'t available in this build.';

  @override
  String get mapNavRetry => 'Retry';

  @override
  String get mapNavWalkingWarning =>
      'Walking routes are in beta — sidewalks and paths may be missing, so use caution.';

  @override
  String get mapNavWarningsTitle => 'Route notices';

  @override
  String get mapNavDisclosureTitle => 'Use Google Maps for directions?';

  @override
  String get mapNavDisclosureBody =>
      'To show a walking route, your current location is sent to Google Maps. Otherwise your location stays on your device and isn\'t shared.';

  @override
  String get mapNavDisclosureAccept => 'Use Google Maps';

  @override
  String get wayfindingMapUnavailable =>
      'Map not shown. The written directions below are complete on their own.';

  @override
  String get mapNavDisclosureBodyPreview =>
      'To show a walking route, the simulated preview location — not your real position — is sent to Google Maps.';

  @override
  String get creditsMapsLicences => 'Google Maps licences';

  @override
  String get previewLocationBadge => 'Simulated location';

  @override
  String get settingsPreviewTitle => 'Preview from anywhere';

  @override
  String get settingsPreviewBody =>
      'Not on campus yet? Turn this on to see the map, compass and nearby list as they\'ll look on the night. The position shown is simulated, not your real location.';

  @override
  String get settingsEraseTitle => 'Delete my data';

  @override
  String get settingsEraseBody =>
      'Clears your saved plan, passport stamps, favourites and your Google Maps choice. Your language and theme settings are kept.';

  @override
  String get settingsEraseConfirmTitle => 'Delete data stored on this device?';

  @override
  String get settingsEraseConfirmBody =>
      'This permanently deletes data stored by this app on this device. It cannot undo anything already sent to Google.';

  @override
  String get settingsEraseConfirmAction => 'Delete';

  @override
  String get settingsEraseCancel => 'Cancel';

  @override
  String get settingsEraseDone => 'Deleted.';

  @override
  String get settingsEraseFailed =>
      'Couldn\'t delete your data. Please try again.';

  @override
  String get mapDisplayDisclosureTitle => 'Load the Google map here?';

  @override
  String get mapDisplayDisclosureBody =>
      'This screen draws your walking route on a Google map. Google receives the map request and the technical request and device information it needs to serve it. This screen does not use your location.\n\nThe same choice also covers walking directions elsewhere in the app — if you ask for those, your location is sent to Google.';

  @override
  String get mapNavDisclosureDecline => 'Not now';

  @override
  String get settingsRevokeGoogleConsent => 'Revoke Google Maps access';

  @override
  String get settingsGoogleMapsNotice =>
      'When you use Google Maps directions, your location is sent to Google. Google\'s terms and privacy policy apply.';

  @override
  String get mapModeMap => 'Map';

  @override
  String get mapModePanorama => '360°';

  @override
  String get mapModeCompass => 'Compass';

  @override
  String get compassFindingNorth => 'Finding north…';

  @override
  String get compassFindingYourLocation => 'Finding your location…';

  @override
  String get compassUnavailable => 'Compass unavailable on this device';

  @override
  String get compassUnavailableBody =>
      'Showing what\'s nearby with directions instead.';

  @override
  String get compassNearbyTitle => 'Nearby';

  @override
  String get compassFilterHint => 'Filter places';

  @override
  String get compassNothingNearby => 'Nothing nearby to point to yet.';

  @override
  String get compassLocationNeeded => 'Turn on location to find your way';

  @override
  String get compassEnableLocation => 'Enable location';

  @override
  String get compassYouAreHere => 'You\'re basically there';

  @override
  String get compassApproximate => 'Approximate location';

  @override
  String get compassUnlocatable => 'Location unknown — see the printed map';

  @override
  String get homeNothingRunningNow =>
      'Nothing running this minute — check what’s next.';

  @override
  String get homeFactColdTitle => 'It gets cold and dark';

  @override
  String get homeFactColdBody =>
      'Bring a jacket and a torch. Red-light mode is best near the telescopes — it protects everyone’s night vision.';

  @override
  String get homeFactBookingTitle => 'Some shows need pre-booking';

  @override
  String get homeFactBookingBody =>
      'The magic shows and Destination Moon need seats booked at the time of ticket purchase.';

  @override
  String get homeFactParkingTitle => 'Free parking';

  @override
  String get homeFactParkingBody => 'West 5, West 6 and South 2.';

  @override
  String get homeFactMetroTitle => 'Metro';

  @override
  String get homeFactMetroBody =>
      'Sydney Metro stops at Macquarie University Metro Station, on campus.';

  @override
  String get programClearSearch => 'Clear search';

  @override
  String get programBookedOnly => 'Pre-booked only';

  @override
  String get detailNotFoundTitle => 'Not found';

  @override
  String get detailSessionTimes => 'Session times';

  @override
  String get detailTime => 'Time';

  @override
  String get detailLocation => 'Location';

  @override
  String get detailUnpublishedTimes =>
      'These times are not published in the official program — treat them as a guide.';

  @override
  String get detailPositionUnconfirmed =>
      'The exact position of this location is still being confirmed. Follow signage and ask at an information point.';

  @override
  String get detail360View => '360° view';

  @override
  String detailMarkedOnMap(String letter) {
    return 'Marked $letter on the printed event map';
  }

  @override
  String get myNightClearConfirm => 'Clear';

  @override
  String get settingsTextSizeCardTitle => 'Set text size on your phone';

  @override
  String get settingsPrivacyCardTitle => 'What this app shares';

  @override
  String get settingsMapDataAttribution =>
      'Campus map: Macquarie University. Walking directions and the map they appear on are provided by Google.';

  @override
  String get infoFirstAid => 'First aid';

  @override
  String get infoToilets => 'Toilets';

  @override
  String get infoRegistrationAndInfo => 'Registration and information';

  @override
  String get infoFoodAndDrink => 'Food and drink';

  @override
  String get infoParking => 'Parking';

  @override
  String get infoParkingFree => 'Free event parking';

  @override
  String get infoWalkingFromParking => 'Walking directions from parking';

  @override
  String get infoGettingHere => 'Getting here';

  @override
  String get infoBeforeYouCome => 'Before you come';

  @override
  String get infoDressTitle => 'Dress for standing outside';

  @override
  String get infoDressBody =>
      'The Telescope Park and the Central Courtyard are open ground, and September evenings get cold. Bring a jacket.';

  @override
  String get infoTorchTitle => 'Bring a torch — red light if you have it';

  @override
  String get infoTorchBody =>
      'It gets genuinely dark towards the Observatory, and that is on purpose. White light ruins night vision for everyone around you, so use a red torch mode near the telescopes and turn your phone brightness down.';

  @override
  String get infoBookTitle => 'Book the ticketed shows early';

  @override
  String get infoBookBody =>
      'The physics and chemistry magic shows and Destination Moon need seats pre-booked at the time of ticket purchase.';

  @override
  String get infoChildrenTitle => 'Children must be supervised';

  @override
  String get infoChildrenBody =>
      'Children must be accompanied by a parent or guardian at all times in the Kids’ space.';

  @override
  String get infoCloudTitle => 'If it clouds over';

  @override
  String get infoCloudBody =>
      'Telescope viewing depends on the weather, but the planetarium sessions at the Sport and Aquatic Centre run regardless.';

  @override
  String get infoCredits => 'Credits';

  @override
  String get previewSection => 'Preview';

  @override
  String get previewTitle => 'Preview event night';

  @override
  String previewBody(String date) {
    return 'Set the app’s clock to any point on $date to see what the program looks like at that moment. Useful before the night; leave it off during the event.';
  }

  @override
  String get previewChooseTime => 'Choose a time';

  @override
  String get previewBackToRealTime => 'Back to real time';

  @override
  String previewBanner(String time) {
    return 'Previewing $time on event night';
  }

  @override
  String get previewExit => 'Exit';

  @override
  String get passportTitle => 'Astronomy Passport';

  @override
  String get venueNoDirections =>
      'We don’t have written walking directions to here yet. Ask at an information point in the Central Courtyard.';

  @override
  String get venueNothingScheduled => 'Nothing scheduled here tonight.';

  @override
  String get parkingNoConfirmedPosition =>
      'We don’t have a confirmed position for this car park yet — follow on-site signage.';

  @override
  String creditsEventMaterialsBody(String host, String faculty, String cricos) {
    return 'Event materials, campus map and branding © $host, $faculty. $cricos.';
  }

  @override
  String creditsHeroImageBody(String credit) {
    return 'Hero image: “$credit”. Used with permission for this project.';
  }

  @override
  String get wayfindingReset => 'Reset';

  @override
  String get wayfindingNoPairTitle => 'No directions for that pair yet';

  @override
  String get wayfindingNoPairBody =>
      'We don’t have a written route between those two points. Try the Central Courtyard as a staging point — most routes run through it — or ask at an information point.';

  @override
  String get wayfindingDraftRoute =>
      'These directions are a draft and have not yet been walked and verified on campus at night. Follow event signage and marshals if they differ.';

  @override
  String get wayfindingStepFree => 'Step-free access along this route.';

  @override
  String get wayfindingNotStepFree => 'This route is not step-free.';

  @override
  String get settingsLanguageSystemHint =>
      'Falls back to English if your device language isn’t available.';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguagePersian => 'فارسی';

  @override
  String get creditsMapDataBody =>
      'Campus map: Macquarie University. Walking directions and the map they appear on are provided by Google.';

  @override
  String eventSourceNote(String note) {
    return 'Source: $note';
  }

  @override
  String eventMapReference(String ref) {
    return 'Marked $ref on the printed event map';
  }

  @override
  String get timingOnTheNight => 'On the night';

  @override
  String get categoryActivities => 'Activities';

  @override
  String get categoryShortTalks => 'Short talks';

  @override
  String get categoryKeynote => 'Keynote lecture';

  @override
  String get categoryFeaturedPresentations => 'Featured presentations';

  @override
  String get bandEarlyEvening => '4–6pm';

  @override
  String get bandEvening => '6–8pm';

  @override
  String get bandLateEvening => '8–10pm';

  @override
  String get tabSettings => 'Settings';

  @override
  String creditsDevelopedBy(String first, String second) {
    return 'Developed by $first and $second';
  }

  @override
  String get settingsHaptics => 'Haptics';

  @override
  String get settingsHapticsBody =>
      'A gentle vibration when you tap buttons and save activities. Turn it off if you prefer no vibration.';

  @override
  String get settingsCreditsDevelopers => 'Developed by';

  @override
  String get settingsYourData => 'Your data';

  @override
  String passportStampProgress(int count, int total) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$countString of $totalString stamps';
  }
}
