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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString activities saved',
      one: '1 activity saved',
    );
    return '$_temp0';
  }

  @override
  String myNightSessionOf(int index, int total) {
    final intl.NumberFormat indexNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Session $indexString of $totalString';
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
  String get timingTimeNotPublished => 'Time not published';

  @override
  String get programTimeNotPublishedHeading => 'Time not published';

  @override
  String get programTimeNotPublishedBlurb =>
      'The official programme doesn’t list times for these. Ask at an information point on the night.';

  @override
  String get timingEndNotPublished => 'Finish time not published';

  @override
  String get timingOpenAllEvening => 'Open all night';

  @override
  String timingStartingWithin(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'In the next $minutesString minutes';
  }

  @override
  String get phaseTonight => 'Tonight';

  @override
  String get phaseStartsSoon => 'Starts soon';

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
      'Venues, toilets, parking and walking directions';

  @override
  String get homeOpenMapBodyNoWayfinding => 'Venues, toilets and parking';

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
  String get quickAccessInformationPoints => 'Information points';

  @override
  String get quickAccessWalkingRoutes => 'Walking routes';

  @override
  String get quickAccessToiletsAll => 'All locations';

  @override
  String get programTonight => 'Tonight';

  @override
  String get programSections => 'Sections';

  @override
  String get programSearchHint => 'Search talks, activities, presenters';

  @override
  String get programFilterByTime => 'Filter by time';

  @override
  String get programFilterByActivity => 'Filter by activity';

  @override
  String get programAllTimes => 'All times';

  @override
  String get programAllActivities => 'All activities';

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
  String get mapAttributionCampus =>
      'Campus map: Astronomy Open Night programme';

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
  String get mapFavoritesEmptyHint => 'Activities you save appear here.';

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
  String get panoramaSolarWalkTitle => 'Solar system walk';

  @override
  String get panoramaSolarWalkSubtitle =>
      'Central Courtyard to Telescope Park, in 360°';

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
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'This app follows your device text size, up to $percentString% — every screen is tested at that size. Change it in your phone’s display or accessibility settings.';
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
      'No account or advertising. Stamps, favourites, your plan and preferences stay in local app or browser storage; iOS and Android system backups may include app data.\n\nNative camera images stay on your device. On Android, Google ML Kit reports technical/usage diagnostics and installation identifiers. Web uses manual passport codes without a camera.\n\nLocation supports the campus map and compass. After you agree, walking directions send the route origin and destination to Google. Google Maps also receives technical data, identifiers, diagnostics and map interactions. Cloudflare processes web requests to deliver the site.\n\nRead the Privacy Policy below for details, retention, deletion and contact information.';

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
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'About $minutesString min';
  }

  @override
  String wayfindingApproxMetres(int metres) {
    final intl.NumberFormat metresNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metresString = metresNumberFormat.format(metres);

    return '~$metresString m';
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
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
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
  String get mapPlaceListOnly => 'Details only — not shown on the map';

  @override
  String mapNavDistanceMeters(int meters) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
  }

  @override
  String mapNavDistanceKm(String km) {
    return '$km km';
  }

  @override
  String mapNavEtaMin(int mins) {
    final intl.NumberFormat minsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minsString = minsNumberFormat.format(mins);

    return '$minsString min';
  }

  @override
  String mapNavEtaHourMin(int hours, int mins) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minsString = minsNumberFormat.format(mins);

    return '$hoursString hr $minsString min';
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
  String get mapNavPlatformUnsupported =>
      'Walking directions with the live map work on the iPhone and Android apps. This build can’t show the Google map.';

  @override
  String get mapNavUnavailable =>
      'Google Maps is not configured yet. Please add the Google Maps API key to enable directions.';

  @override
  String get mapNavOffCampusOrigin =>
      'Walking directions are available once you are on campus.';

  @override
  String get mapNavDestinationOffCampus =>
      'This place isn\'t on the Astronomy Open Night campus map.';

  @override
  String get mapNavRouteUnavailable =>
      'Walking route is temporarily unavailable. The map still shows your destination.';

  @override
  String get mapNavFindingRoute => 'Finding your walking route…';

  @override
  String get mapNavRetry => 'Retry';

  @override
  String get mapNavWarningsTitle => 'Route notices';

  @override
  String get mapNavStepsTitle => 'Walking directions';

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
  String get settingsEnableGoogleConsent =>
      'Turn Google Maps directions back on';

  @override
  String get settingsGoogleMapsNotice =>
      'When you use Google Maps directions, your location is sent to Google. Google\'s terms and privacy policy apply.';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsPrivacyPolicyUnavailable =>
      'Couldn\'t open the privacy policy. Please try again.';

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
      'Still showing each place\'s direction, north-up.';

  @override
  String get compassNearbyTitle => 'Nearby';

  @override
  String get compassFilterHint => 'Filter places';

  @override
  String get compassClusterLegend => 'A number = how many places lie that way.';

  @override
  String get compassPointHere => 'Point the compass here';

  @override
  String get compassAimedHere => 'Compass pointed here';

  @override
  String get compassNothingNearby => 'Nothing nearby to point to yet.';

  @override
  String compassUnconfirmedHeading(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString places with no confirmed location',
      one: '1 place with no confirmed location',
    );
    return '$_temp0';
  }

  @override
  String get compassUnconfirmedBlurb =>
      'We don’t have a confirmed position for these, so the compass can’t point to them. Check the printed map or ask at an information point.';

  @override
  String get compassNoConfirmedTargets =>
      'No confirmed locations to point to from here.';

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
      'Bring a jacket and a torch — use red-light mode near the telescopes.';

  @override
  String get homeFactBookingTitle => 'Some shows need pre-booking';

  @override
  String get homeFactBookingBody =>
      'The magic shows and Destination Moon need seats pre-booked.';

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
      'Campus map: Astronomy Open Night 2026 programme. Walking directions and the map they appear on are provided by Google.';

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
  String get creditsEventMaterialsBody =>
      'Programme content follows the published Astronomy Open Night 2026 event materials.';

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
  String get settingsLanguagePersian => 'Persian';

  @override
  String get creditsMapDataBody =>
      'Campus map: Astronomy Open Night 2026 programme. Walking directions and the map they appear on are provided by Google.';

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
  String get creditsAcknowledgement =>
      'Two student app developers, in appreciation of the Astronomy Open Night team.';

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

  @override
  String get settingsPassportPreviewTitle => 'Preview the Astronomy Passport';

  @override
  String get settingsPassportPreviewBody =>
      'The station codes are live, so stamps can be collected on any build. Turn this on only to practise the rally away from the venue signs — a preview badge shows while it\'s on. Practice stamps stay on this device like real ones; clear them with Delete my data.';

  @override
  String get passportPreviewBadge => 'Preview stamps';

  @override
  String passportProgress(int count, int total) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$countString / $totalString stamps';
  }

  @override
  String get passportOpensOnEventNight =>
      'Astronomy Passport opens on event night';

  @override
  String get passportStartHint => 'Scan or enter a venue code to start';

  @override
  String get passportHowItWorks =>
      'Each of the nine venues has a QR sign. Scan it (or type its code) to collect the stamp and unlock an astronomy fact.';

  @override
  String get passportOneMoreToGo => 'Just 1 more to go!';

  @override
  String get passportSaveFailed =>
      'Your progress may not be saved on this device.';

  @override
  String get passportViewReward => 'View your reward';

  @override
  String get passportScanOrEnter => 'Scan or enter a code';

  @override
  String get passportResetTitle => 'Reset passport?';

  @override
  String get passportResetBody =>
      'This clears all collected stamps on this device.';

  @override
  String get passportResetConfirm => 'Reset';

  @override
  String get passportScanTitle => 'Collect a stamp';

  @override
  String get passportScanCollected => 'Stamp collected!';

  @override
  String get passportScanAlready => 'You already have this one.';

  @override
  String get passportScanUnknown => 'That\'s not an Astronomy Open Night code.';

  @override
  String get passportScanDisabled =>
      'The passport isn\'t live yet — see staff at an information point.';

  @override
  String get passportScanQrButton => 'Scan QR code';

  @override
  String get passportEnterCodeButton => 'Enter a code';

  @override
  String get passportEnterCodeHint => 'Enter the code from the venue sign';

  @override
  String get passportCodeLabel => 'Code';

  @override
  String get passportAddStamp => 'Add stamp';

  @override
  String get passportScanAnother => 'Scan another';

  @override
  String get mapSearchParkingTitle => 'Parking & walking routes';

  @override
  String get mapSearchParkingBody =>
      'West 5, West 6 and South 2 — get walking directions to and from the Central Courtyard.';

  @override
  String get mapDirections => 'Directions';

  @override
  String get venueCatEventVenue => 'Event venue';

  @override
  String get venueCatInformationPoint => 'Information point';

  @override
  String get venueCatRegistration => 'Registration';

  @override
  String get venueCatToilets => 'Toilets';

  @override
  String get venueCatFirstAid => 'First aid';

  @override
  String get venueCatFoodAndDrink => 'Food and drink';

  @override
  String get venueCatParking => 'Parking';

  @override
  String get venueCatMetro => 'Metro station';

  @override
  String get venueCatOther => 'Other';

  @override
  String get timeRelativeNow => 'now';

  @override
  String timeRelativeIn(String duration) {
    return 'in $duration';
  }

  @override
  String get timeRelativeEnded => 'ended';

  @override
  String get timeRelativeEndingNow => 'ending now';

  @override
  String timeDurationHours(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursString hr';
  }

  @override
  String listAnd(String items, String last) {
    return '$items and $last';
  }

  @override
  String get passportRewardIncomplete =>
      'Your passport is not complete yet — keep collecting stamps.';

  @override
  String get passportRewardCompleteTitle => 'Passport complete';

  @override
  String passportRewardAllCollected(int total) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'All $totalString stamps collected!';
  }

  @override
  String get passportRewardShowStaff =>
      'Show this to staff at the prize booth.';

  @override
  String get passportScanWebUnavailable =>
      'Scanning isn\'t available on the web — enter the code below.';

  @override
  String get passportScanCameraUnavailable =>
      'Camera unavailable — enter the code from the sign instead.';

  @override
  String get passportScanTorch => 'Torch';

  @override
  String passportCellCollected(String name) {
    return '$name, stamp collected';
  }

  @override
  String passportCellNotCollected(String name) {
    return '$name, not yet collected';
  }

  @override
  String get passportCellOpensFact => 'Opens astronomy fact';

  @override
  String get passportFactDraftNote =>
      'Draft — awaiting review by the astronomy team.';

  @override
  String get actionClose => 'Close';

  @override
  String get panoramaComingSoon => 'Coming soon';

  @override
  String get panoramaDemoFlag => 'Demo 360° — sample imagery, not this venue';

  @override
  String get panoramaPreviewUnavailable => '360° preview unavailable';

  @override
  String panoramaCardComingSoon(String name) {
    return '$name, coming soon';
  }

  @override
  String panoramaCardTour(String name) {
    return '$name, 360 tour';
  }

  @override
  String panoramaCardDemoTour(String name) {
    return '$name, demo 360 tour';
  }

  @override
  String get passportCameraSettings => 'Open app settings';

  @override
  String get passportScannerPrivacy =>
      'Camera images stay on your device. On Android, Google ML Kit reports technical and usage diagnostics. You can enter the printed code instead. See Privacy Policy in Settings.';

  @override
  String get settingsPrivacyPolicyBody =>
      'This Privacy Policy applies specifically to the Astronomy Open Night 2026 app, and covers its iOS, Android and web versions. It does not apply to other Syllabus Sync products or to the Macquarie University website. Astronomy Open Night was developed by the Syllabus Sync team (Leo Alavi and Mohammad Raouf Abedini) for the Astronomy Night – FSE Outreach Team, which runs the event and holds the copyright. It is published under Leo Alavi\'s store developer account, and Leo Alavi is the App Store seller. The app is not affiliated with, endorsed or sponsored by any university, and the developers do not own or run the event; official event information and support are provided through the official event website. The syllabus-sync.app domain is the technical host of this policy and the web app, which does not make Astronomy Open Night a Syllabus Sync product. This policy covers everyone who uses the app. Last updated 10 September 2026.\n\nWhat the app collects\n\nThere is no account, sign-in, advertising or developer-operated analytics service. There is no tracking, and we do not sell your personal data. We do not operate a server that holds your saved plan or stamps.\n\nThe app stores passport stamps, favourites, your saved plan, Google Maps consent and your preferences on your device. The web version stores these in your browser. Your device\'s own backup (iCloud or device backups on iOS; system backups or device transfers on Android) may include that local data, according to your device settings.\n\nLocation\n\nLocation is optional and the app works without it. If you allow it, the app uses your location on your device to show where you are on the campus map and to point the compass toward a venue. The compass also reads your device\'s motion sensor to tell which way you are facing; that reading never leaves your device.\n\nWhen you request walking directions and agree to Google Maps, the app sends the route origin (which may be your precise or approximate location) and the destination to Google over HTTPS. Until you agree, the app loads no Google map and sends no request.\n\nGoogle Maps and walking directions\n\nThe campus map is an image stored inside the app and works offline. Walking directions on a Google map are the one exception, and the app asks before using them.\n\nTo provide and improve its services, Google Maps also receives map requests, your IP address, device and app information, an SDK-specific identifier, crash and performance diagnostics, usage data and map interactions. On web, Google receives device and browser information with map and directions requests. You can revoke your Google Maps choice at any time in Settings.\n\nCamera and QR scanning\n\nThe app uses the camera for one purpose: reading the QR code on a venue sign for the Astronomy Passport. It starts only when you tap Scan. The app processes camera images on your device and never saves or uploads them.\n\nOn Android, the QR scanner uses Google ML Kit, which reports device and app information, installation identifiers, and performance and usage diagnostics to Google over HTTPS. You can type the printed station code instead of using the camera.\n\nThe web version does not open the camera: the Astronomy Passport uses manual code entry, where you type the printed station code. No image is captured or uploaded.\n\nWeb hosting and external links\n\nCloudflare hosts the web app and these pages. Loading them sends your IP address, requested URL and browser request information to Cloudflare so it can deliver and protect the site. This hosting traffic is separate from the app\'s locally saved plan and stamps.\n\nOpening an external link, including the official event website or Google Maps, sends a request to that provider. Its own privacy policy then applies.\n\nRetention and deletion\n\nSaved stamps, favourites and plans remain until you delete them. In the app, Settings, then Delete my data, clears these items and your Google Maps consent; language and appearance preferences are retained.\n\nDeleting data in the app does not delete data that Google has already received, or copies held in system backups. Google controls retention and deletion of its own service data under its privacy policy. Removing the mobile app removes its local app data but may leave system backups. On web, clear this site\'s data in your browser to remove all locally saved preferences as well.\n\nSecurity\n\nMobile local storage uses the operating system\'s app sandbox. The web version uses browser storage for this site. Neither provides a promise of absolute security.\n\nChildren\n\nThe app is intended for general audiences attending a public event. It has no account and asks for no personal details from anyone, including children. The third-party services and hosting described above still process their disclosed data when used. The app does not link saved plans or stamps to an account.\n\nChanges\n\nIf this policy changes, we will update this page and the date above.\n\nContact\n\nPrivacy questions and data requests about the app: leo@leoalavi.dev. That address reaches the developer account holder, who can act on the app itself.\n\nEvent information and event support: astronomyopennight@mq.edu.au, or the official event website.\n\nAstronomy Open Night 2026\n\nDeveloped by the Syllabus Sync team (Leo Alavi and Mohammad Raouf Abedini) for the Astronomy Night – FSE Outreach Team.\n\nOfficial event information and support: https://event.mq.edu.au/astronomy-open-night/\n\nContact: astronomyopennight@mq.edu.au';

  @override
  String get webPrivacyTitle => 'Privacy';

  @override
  String webPrivacyLastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String webPrivacyIntro(String developer, String forTeam) {
    return 'This is the privacy notice for the Astronomy Open Night 2026 web app. The app has no account and no sign-in, and it runs entirely in your browser. It is an event companion application developed by $developer for $forTeam. Official event information and support are provided through the official event website.';
  }

  @override
  String get webPrivacyStorageHeading => 'What the app stores in your browser';

  @override
  String get webPrivacyStorageBody =>
      'Your plan, stamps, favourite places, Google Maps consent and preferences are stored in your browser. We do not receive that saved data. Delete my data in Settings clears the plan, stamps, favourites and Maps consent, retaining language and appearance. Clearing this site\'s data in your browser also removes those preferences.';

  @override
  String get webPrivacyLocationHeading => 'Location';

  @override
  String get webPrivacyLocationBody =>
      'The campus map works without location. If you allow it, your browser shares your position with the page so it can show where you are on the map. It is used only in the page, is not sent to us and is not stored. If you deny location, the map still works.';

  @override
  String get webPrivacyCameraHeading => 'Camera and QR codes';

  @override
  String get webPrivacyCameraBody =>
      'On the web app the Astronomy Passport uses manual code entry: you type the short code printed on each venue\'s sign. The web app does not open your camera and does not upload any images.';

  @override
  String get webPrivacyMapsHeading => 'Google Maps and walking directions';

  @override
  String get webPrivacyMapsBody =>
      'The campus map is an image built into the app and needs no connection. If you choose to load a Google map or ask for walking directions, Google receives that request — including the start and end points of the route (the start may be your precise or approximate location), your IP address, and device and browser information — under its own privacy policy (https://policies.google.com/privacy). No Google map is loaded and no request is sent until you agree, and you can change that choice in Settings.';

  @override
  String get webPrivacyAnalyticsHeading => 'No tracking';

  @override
  String get webPrivacyAnalyticsBody =>
      'The app contains no developer-operated analytics, advertising or tracking pixels, and we do not sell your personal data. Cloudflare processes web requests to deliver and protect the site. Google Maps receives data only after consent; external links follow their own providers\' privacy policies.';

  @override
  String get webPrivacyRetentionHeading => 'Keeping and deleting your data';

  @override
  String get webPrivacyRetentionBody =>
      'Because everything is stored only in your browser, it stays until you remove it. Settings → Delete my data clears your saved plan, stamps, favourites and Google Maps consent; your language and appearance preferences are kept. This does not delete data already received by Google.';

  @override
  String get webPrivacyContactHeading => 'Contact and support';

  @override
  String get webPrivacyContactBody =>
      'For app privacy questions, contact leo@leoalavi.dev. For event information and event support, use the official event website.';

  @override
  String webPrivacyCredit(String developer, String forTeam) {
    return 'Developed by $developer for $forTeam. Official event information and support: the official event website.';
  }

  @override
  String get infoOfficialWebsite => 'Official event website';

  @override
  String get infoOfficialWebsiteSubtitle =>
      'Times, tickets and updates from the official event website';

  @override
  String commonDevelopedByFooter(String developer) {
    return 'Built by $developer';
  }

  @override
  String get webPrivacyPageTitle => 'Astronomy Open Night 2026: Privacy Policy';

  @override
  String get webPrivacyScope =>
      'This policy applies specifically to the Astronomy Open Night 2026 app. It does not apply to any other website or application.';

  @override
  String get webPrivacyPublishedLinkLabel =>
      'Read the published Privacy Policy';
}
