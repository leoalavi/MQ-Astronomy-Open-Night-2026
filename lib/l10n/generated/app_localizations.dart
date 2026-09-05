import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AonL10n
/// returned by `AonL10n.of(context)`.
///
/// Applications need to include `AonL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AonL10n.localizationsDelegates,
///   supportedLocales: AonL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AonL10n.supportedLocales
/// property.
abstract class AonL10n {
  AonL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AonL10n of(BuildContext context) {
    return Localizations.of<AonL10n>(context, AonL10n)!;
  }

  static const LocalizationsDelegate<AonL10n> delegate = _AonL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// Official event name. Proper noun — never translate freely; use the organisers' approved rendering for the locale, or keep the English.
  ///
  /// In en, this message translates to:
  /// **'Astronomy Open Night'**
  String get eventName;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get tabProgram;

  /// Bottom navigation label for the saved-plan tab. MUST stay very short — it clips past about 6 characters in a five-tab bar on a 320pt phone.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get tabMyNight;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get tabInfo;

  /// Name of the saved-itinerary feature. Evening event, so night vocabulary — the Open Day equivalent is 'Your Day'.
  ///
  /// In en, this message translates to:
  /// **'My Night'**
  String get myNight;

  /// No description provided for @myNightEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your night is empty'**
  String get myNightEmptyTitle;

  /// No description provided for @myNightEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the star on any activity to plan your night. We’ll line everything up in time order and tell you where to go.'**
  String get myNightEmptyBody;

  /// Home card heading pointing at the next saved activity
  ///
  /// In en, this message translates to:
  /// **'Next in {planName}'**
  String myNightNext(String planName);

  /// No description provided for @myNightSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 activity saved} other{{count} activities saved}}'**
  String myNightSavedCount(int count);

  /// Shown when one activity runs more than once
  ///
  /// In en, this message translates to:
  /// **'Session {index} of {total}'**
  String myNightSessionOf(int index, int total);

  /// No description provided for @myNightClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear {planName}?'**
  String myNightClearTitle(String planName);

  /// No description provided for @myNightClearBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every saved activity. It can’t be undone.'**
  String get myNightClearBody;

  /// No description provided for @myNightAllFinished.
  ///
  /// In en, this message translates to:
  /// **'Everything you saved has finished. What a night.'**
  String get myNightAllFinished;

  /// No description provided for @myNightConflictBanner.
  ///
  /// In en, this message translates to:
  /// **'Some of your saved activities run at the same time. They’re flagged below — most run more than once, so check for another session.'**
  String get myNightConflictBanner;

  /// Names the clashing activities
  ///
  /// In en, this message translates to:
  /// **'Overlaps {titles}'**
  String myNightConflictOverlaps(String titles);

  /// No description provided for @myNightLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open your saved plan'**
  String get myNightLoadFailedTitle;

  /// No description provided for @myNightLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your saved activities are stored on this device. Try again in a moment.'**
  String get myNightLoadFailedBody;

  /// No description provided for @timingHappeningNow.
  ///
  /// In en, this message translates to:
  /// **'Happening now'**
  String get timingHappeningNow;

  /// No description provided for @timingStartingSoon.
  ///
  /// In en, this message translates to:
  /// **'Starting soon'**
  String get timingStartingSoon;

  /// Evening event. The Open Day equivalent would be 'Later today'.
  ///
  /// In en, this message translates to:
  /// **'Later tonight'**
  String get timingLaterTonight;

  /// No description provided for @timingFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get timingFinished;

  /// Status for a programme entry the official PDF gives no time for — never Happening now / Up next
  ///
  /// In en, this message translates to:
  /// **'Time not published'**
  String get timingTimeNotPublished;

  /// Programme section heading grouping activities with no published time
  ///
  /// In en, this message translates to:
  /// **'Time not published'**
  String get programTimeNotPublishedHeading;

  /// Explains the time-not-published group so it does not read as a bug
  ///
  /// In en, this message translates to:
  /// **'The official programme doesn’t list times for these. Ask at an information point on the night.'**
  String get programTimeNotPublishedBlurb;

  /// Qualifier shown where only a start time is official
  ///
  /// In en, this message translates to:
  /// **'Finish time not published'**
  String get timingEndNotPublished;

  /// Timing label for a full-event / open-all-night activity (available the whole evening, not a scheduled session)
  ///
  /// In en, this message translates to:
  /// **'Open all night'**
  String get timingOpenAllEvening;

  /// No description provided for @timingStartingWithin.
  ///
  /// In en, this message translates to:
  /// **'In the next {minutes} minutes'**
  String timingStartingWithin(int minutes);

  /// No description provided for @phaseTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get phaseTonight;

  /// No description provided for @phaseStartsSoon.
  ///
  /// In en, this message translates to:
  /// **'Starts soon'**
  String get phaseStartsSoon;

  /// No description provided for @phaseHappeningNow.
  ///
  /// In en, this message translates to:
  /// **'Happening now'**
  String get phaseHappeningNow;

  /// No description provided for @phaseEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get phaseEndingSoon;

  /// No description provided for @phaseEnded.
  ///
  /// In en, this message translates to:
  /// **'This event has finished'**
  String get phaseEnded;

  /// No description provided for @homeUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get homeUpNext;

  /// No description provided for @homeNothingRightNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing running this minute — check what’s next.'**
  String get homeNothingRightNow;

  /// Link to the full time-sliced programme
  ///
  /// In en, this message translates to:
  /// **'See the whole {period}'**
  String homeSeeWholeEvent(String period);

  /// No description provided for @homeOpenMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Open the campus map'**
  String get homeOpenMapTitle;

  /// No description provided for @homeOpenMapBody.
  ///
  /// In en, this message translates to:
  /// **'Venues, toilets, parking and walking directions'**
  String get homeOpenMapBody;

  /// No description provided for @homeOpenMapBodyNoWayfinding.
  ///
  /// In en, this message translates to:
  /// **'Venues, toilets and parking'**
  String get homeOpenMapBodyNoWayfinding;

  /// No description provided for @homeQuickAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your way to'**
  String get homeQuickAccessTitle;

  /// No description provided for @homeGoodToKnow.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get homeGoodToKnow;

  /// No description provided for @homeImageCredit.
  ///
  /// In en, this message translates to:
  /// **'Image credit'**
  String get homeImageCredit;

  /// No description provided for @quickAccessTelescopes.
  ///
  /// In en, this message translates to:
  /// **'Telescopes'**
  String get quickAccessTelescopes;

  /// No description provided for @quickAccessPlanetariums.
  ///
  /// In en, this message translates to:
  /// **'Planetariums'**
  String get quickAccessPlanetariums;

  /// No description provided for @quickAccessTalks.
  ///
  /// In en, this message translates to:
  /// **'Talks'**
  String get quickAccessTalks;

  /// No description provided for @quickAccessKids.
  ///
  /// In en, this message translates to:
  /// **'Kids’ activities'**
  String get quickAccessKids;

  /// No description provided for @quickAccessFood.
  ///
  /// In en, this message translates to:
  /// **'Food and drink'**
  String get quickAccessFood;

  /// No description provided for @quickAccessToilets.
  ///
  /// In en, this message translates to:
  /// **'Toilets'**
  String get quickAccessToilets;

  /// No description provided for @quickAccessFirstAid.
  ///
  /// In en, this message translates to:
  /// **'First aid'**
  String get quickAccessFirstAid;

  /// No description provided for @quickAccessParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get quickAccessParking;

  /// No description provided for @quickAccessInformationPoints.
  ///
  /// In en, this message translates to:
  /// **'Information points'**
  String get quickAccessInformationPoints;

  /// No description provided for @quickAccessWalkingRoutes.
  ///
  /// In en, this message translates to:
  /// **'Walking routes'**
  String get quickAccessWalkingRoutes;

  /// Subtitle on the Home 'Toilets' shortcut, which opens a chooser listing every toilet location.
  ///
  /// In en, this message translates to:
  /// **'All locations'**
  String get quickAccessToiletsAll;

  /// Segmented-control label for the time-sliced programme view
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get programTonight;

  /// Segmented-control label for the printed programme's own sections
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get programSections;

  /// No description provided for @programSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search talks, activities, presenters'**
  String get programSearchHint;

  /// Count of programme items when no filter is applied.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 item in the program} other{{count} items in the program}}'**
  String programItemCount(int count);

  /// Count when a filter is applied: how many of the whole programme match.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} shown'**
  String programFilteredCount(int shown, int total);

  /// No description provided for @programNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get programNoMatchTitle;

  /// No description provided for @programNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try removing a filter or searching for something else.'**
  String get programNoMatchBody;

  /// No description provided for @programClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get programClearFilters;

  /// No description provided for @programPreBookingRequired.
  ///
  /// In en, this message translates to:
  /// **'Pre-booking required'**
  String get programPreBookingRequired;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get actionSaved;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionWalkThere.
  ///
  /// In en, this message translates to:
  /// **'Walk there'**
  String get actionWalkThere;

  /// No description provided for @actionShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get actionShowOnMap;

  /// No description provided for @actionBrowseProgram.
  ///
  /// In en, this message translates to:
  /// **'Browse the program'**
  String get actionBrowseProgram;

  /// No description provided for @actionRemoveFromPlan.
  ///
  /// In en, this message translates to:
  /// **'Remove from plan'**
  String get actionRemoveFromPlan;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Screen-reader label for the unsaved star button
  ///
  /// In en, this message translates to:
  /// **'Save {title} to {planName}'**
  String a11ySaveToPlan(String title, String planName);

  /// No description provided for @a11yRemoveFromPlan.
  ///
  /// In en, this message translates to:
  /// **'Remove {title} from {planName}'**
  String a11yRemoveFromPlan(String title, String planName);

  /// No description provided for @snackSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {planName}'**
  String snackSavedTo(String planName);

  /// No description provided for @snackRemovedFrom.
  ///
  /// In en, this message translates to:
  /// **'Removed from {planName}'**
  String snackRemovedFrom(String planName);

  /// No description provided for @mapTitle.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTitle;

  /// No description provided for @mapWalkingDirections.
  ///
  /// In en, this message translates to:
  /// **'Walking directions'**
  String get mapWalkingDirections;

  /// Opens the immersive panorama for a venue
  ///
  /// In en, this message translates to:
  /// **'Look inside in 360°'**
  String get mapLookInside360;

  /// No description provided for @mapOnHereTonight.
  ///
  /// In en, this message translates to:
  /// **'On here tonight'**
  String get mapOnHereTonight;

  /// Attribution overlaid on the AON campus basemap. Names the SOURCE, not a copyright holder: MQ ownership of the cartographic master is unconfirmed under spec §8.6, so asserting © on their behalf is a claim we cannot back.
  ///
  /// In en, this message translates to:
  /// **'Campus map: Macquarie University'**
  String get mapAttributionCampus;

  /// No description provided for @mapRecentre.
  ///
  /// In en, this message translates to:
  /// **'Recentre'**
  String get mapRecentre;

  /// No description provided for @mapZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get mapZoomOut;

  /// No description provided for @mapSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a place'**
  String get mapSearchTitle;

  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search buildings and venues'**
  String get mapSearchHint;

  /// No description provided for @mapSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get mapSearchTooltip;

  /// No description provided for @mapSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String mapSearchEmpty(String query);

  /// No description provided for @mapFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get mapFavoritesTitle;

  /// No description provided for @mapFavoritesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get mapFavoritesTooltip;

  /// No description provided for @mapFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get mapFavoritesEmpty;

  /// No description provided for @mapFavoritesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Activities you save appear here.'**
  String get mapFavoritesEmptyHint;

  /// No description provided for @mapFavoritesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get mapFavoritesLoading;

  /// No description provided for @mapFavoriteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get mapFavoriteUnavailable;

  /// No description provided for @mapFavoriteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get mapFavoriteAdd;

  /// No description provided for @mapFavoriteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get mapFavoriteRemove;

  /// No description provided for @mapBuildingGridRef.
  ///
  /// In en, this message translates to:
  /// **'Grid {ref}'**
  String mapBuildingGridRef(String ref);

  /// No description provided for @mapCatAcademic.
  ///
  /// In en, this message translates to:
  /// **'Academic'**
  String get mapCatAcademic;

  /// No description provided for @mapCatServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get mapCatServices;

  /// No description provided for @mapCatHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get mapCatHealth;

  /// No description provided for @mapCatFood.
  ///
  /// In en, this message translates to:
  /// **'Food & drink'**
  String get mapCatFood;

  /// No description provided for @mapCatSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get mapCatSports;

  /// No description provided for @mapCatVenue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get mapCatVenue;

  /// No description provided for @mapCatResearch.
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get mapCatResearch;

  /// No description provided for @mapCatResidential.
  ///
  /// In en, this message translates to:
  /// **'Residential'**
  String get mapCatResidential;

  /// No description provided for @mapCatParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get mapCatParking;

  /// No description provided for @mapCatTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get mapCatTransport;

  /// No description provided for @mapCatSmoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking area'**
  String get mapCatSmoking;

  /// No description provided for @mapCatTeaching.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get mapCatTeaching;

  /// No description provided for @mapCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get mapCatOther;

  /// Shown when a venue has no 360 tour. Never expose scene ids or 'not found' errors.
  ///
  /// In en, this message translates to:
  /// **'3D view is not available for this location.'**
  String get panorama360Unavailable;

  /// No description provided for @panorama360Loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the 360° view…'**
  String get panorama360Loading;

  /// No description provided for @panorama360Title.
  ///
  /// In en, this message translates to:
  /// **'360° preview'**
  String get panorama360Title;

  /// 360° picker card subtitle for a venue with real photography. Replaces the demo disclosure, which now shows only for placeholder tours.
  ///
  /// In en, this message translates to:
  /// **'Tap to explore in 360°'**
  String get panoramaTapToExplore;

  /// Title of the pinned card at the top of the 360° picker for the Solar system walk — a route tour along Gymnasium Road, not a lettered map venue.
  ///
  /// In en, this message translates to:
  /// **'Solar system walk'**
  String get panoramaSolarWalkTitle;

  /// Subtitle of the pinned Solar system walk card in the 360° picker. Names the route the walk follows.
  ///
  /// In en, this message translates to:
  /// **'Central Courtyard to Telescope Park, in 360°'**
  String get panoramaSolarWalkSubtitle;

  /// 360° picker card title. Prefixes the venue with the letter the official AON program map prints for it, so the app list and the paper sheet read in the same alphabet.
  ///
  /// In en, this message translates to:
  /// **'{letter} · {name}'**
  String panoramaVenueWithMapLetter(String letter, String name);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow my phone'**
  String get settingsAppearanceSystem;

  /// No description provided for @settingsAppearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// No description provided for @settingsAppearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// No description provided for @settingsAppearanceDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended — kinder to your night vision at the event'**
  String get settingsAppearanceDarkHint;

  /// No description provided for @settingsMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get settingsMotion;

  /// No description provided for @settingsReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// No description provided for @settingsReduceMotionBody.
  ///
  /// In en, this message translates to:
  /// **'Turns off the tab bar and glass animations. Your phone’s own reduce-motion setting is always respected too.'**
  String get settingsReduceMotionBody;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// No description provided for @settingsTextSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Set text size on your phone'**
  String get settingsTextSizeTitle;

  /// No description provided for @settingsTextSizeBody.
  ///
  /// In en, this message translates to:
  /// **'This app follows your device text size, up to {percent}% — every screen is tested at that size. Change it in your phone’s display or accessibility settings.'**
  String settingsTextSizeBody(int percent);

  /// Settings section header for the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Use whatever language the phone is set to.
  ///
  /// In en, this message translates to:
  /// **'Match my device'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About {eventName}'**
  String settingsAbout(String eventName);

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'What this app shares'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'There is no account and no sign-in. Your passport stamps, favourites and saved plan stay on this device. The app collects no analytics.\n\nThe camera is used only to read a QR code, and the image is never stored or sent anywhere.\n\nYour location is used on this device to show where you are on the campus map. It is sent to Google only when you ask for walking directions — and only after you agree.\n\nWayfinding draws its route on a Google map. Loading any Google map sends Google the map request plus the technical request and device information it needs to serve it — but not your location.'**
  String get settingsPrivacyBody;

  /// No description provided for @settingsCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get settingsCredits;

  /// No description provided for @settingsCreditsHeroImage.
  ///
  /// In en, this message translates to:
  /// **'Hero image'**
  String get settingsCreditsHeroImage;

  /// No description provided for @settingsCreditsEventMaterials.
  ///
  /// In en, this message translates to:
  /// **'Event materials'**
  String get settingsCreditsEventMaterials;

  /// No description provided for @settingsCreditsMapData.
  ///
  /// In en, this message translates to:
  /// **'Map data'**
  String get settingsCreditsMapData;

  /// No description provided for @settingsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings unavailable'**
  String get settingsUnavailableTitle;

  /// No description provided for @settingsUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Your preferences couldn’t be opened on this device. The app still works — it just won’t remember this choice.'**
  String get settingsUnavailableBody;

  /// No description provided for @infoTitle.
  ///
  /// In en, this message translates to:
  /// **'Useful information'**
  String get infoTitle;

  /// No description provided for @infoLocationToBeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Location to be confirmed'**
  String get infoLocationToBeConfirmed;

  /// Shown wherever data is a placeholder rather than confirmed by the organisers.
  ///
  /// In en, this message translates to:
  /// **'This detail is still to be confirmed.'**
  String get infoDetailToBeConfirmed;

  /// No description provided for @eventNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'We can’t find that activity'**
  String get eventNotFoundTitle;

  /// No description provided for @eventNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been changed or removed from the program since this link was shared.'**
  String get eventNotFoundBody;

  /// No description provided for @wayfindingTitle.
  ///
  /// In en, this message translates to:
  /// **'Walking directions'**
  String get wayfindingTitle;

  /// Label above the start-point chips (a car park or venue).
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get wayfindingStartingFrom;

  /// Label above the destination chips.
  ///
  /// In en, this message translates to:
  /// **'Going to'**
  String get wayfindingGoingTo;

  /// Nothing chosen yet — distinct from having chosen an unroutable pair.
  ///
  /// In en, this message translates to:
  /// **'Pick a start and a destination'**
  String get wayfindingPickTitle;

  /// Body for the nothing-chosen-yet empty state.
  ///
  /// In en, this message translates to:
  /// **'Choose where you parked and where you’re heading, and we’ll give you written directions for walking it in the dark.'**
  String get wayfindingPickBody;

  /// No description provided for @wayfindingNoRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'No directions for that pair yet'**
  String get wayfindingNoRouteTitle;

  /// No description provided for @wayfindingNoRouteBody.
  ///
  /// In en, this message translates to:
  /// **'We don’t have a written route between those two points. Try the Central Courtyard as a staging point — most routes run through it — or ask at an information point.'**
  String get wayfindingNoRouteBody;

  /// Heading above the numbered walking steps.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get wayfindingDirections;

  /// No description provided for @wayfindingStraightLineNote.
  ///
  /// In en, this message translates to:
  /// **'Straight line shown — this is the general direction, not the exact path. Follow the written directions below.'**
  String get wayfindingStraightLineNote;

  /// No description provided for @wayfindingDraftWarning.
  ///
  /// In en, this message translates to:
  /// **'These directions are a draft and have not yet been walked and verified on campus at night. Follow event signage and marshals if they differ.'**
  String get wayfindingDraftWarning;

  /// No description provided for @wayfindingAboutMinutes.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min'**
  String wayfindingAboutMinutes(int minutes);

  /// No description provided for @wayfindingApproxMetres.
  ///
  /// In en, this message translates to:
  /// **'~{metres} m'**
  String wayfindingApproxMetres(int metres);

  /// Accessibility is UNKNOWN. Must never read as a 'no' — a wrong 'no' turns someone away from a route they could have used.
  ///
  /// In en, this message translates to:
  /// **'Step-free access along this route has not been confirmed yet. Ask at an information point if you need a step-free path.'**
  String get wayfindingStepFreeUnknown;

  /// Map locate button, inactive state
  ///
  /// In en, this message translates to:
  /// **'Show my location'**
  String get locateShow;

  /// Map locate button, active but not following
  ///
  /// In en, this message translates to:
  /// **'Follow my location'**
  String get locateFollow;

  /// Map locate button, following
  ///
  /// In en, this message translates to:
  /// **'Stop following my location'**
  String get locateStopFollowing;

  /// Map locate button, active but the fix is low-accuracy (>200m)
  ///
  /// In en, this message translates to:
  /// **'Location accuracy is low'**
  String get locateLowAccuracy;

  /// Map locate button, permission denied
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locateUnavailable;

  /// Map locate button, device location services off
  ///
  /// In en, this message translates to:
  /// **'Turn on Location Services'**
  String get locateServiceOff;

  /// Banner note shown when the current fix is low-accuracy
  ///
  /// In en, this message translates to:
  /// **'Location accuracy is low'**
  String get mapLowAccuracy;

  /// Banner when the user is outside the campus radius
  ///
  /// In en, this message translates to:
  /// **'You\'re about {km} km from campus'**
  String mapOffCampus(String km);

  /// Shown when a near-campus GPS fix can't be placed on the illustrated map yet
  ///
  /// In en, this message translates to:
  /// **'Locating you on the campus map…'**
  String get mapLocatingOnCampus;

  /// Heading screen title + venue-sheet button
  ///
  /// In en, this message translates to:
  /// **'Point me there'**
  String get pointMeTitle;

  /// No description provided for @pointMeDistanceMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String pointMeDistanceMeters(int meters);

  /// No description provided for @pointMeDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String pointMeDistanceKm(String km);

  /// Heading acquiring state
  ///
  /// In en, this message translates to:
  /// **'Finding north…'**
  String get pointMeFindingNorth;

  /// Shown within the near-target radius
  ///
  /// In en, this message translates to:
  /// **'You\'re basically there'**
  String get pointMeNearby;

  /// Fallback when heading is unsupported/unavailable
  ///
  /// In en, this message translates to:
  /// **'The live arrow needs a phone with a compass sensor. Here\'s the direction and distance.'**
  String get pointMeNoCompass;

  /// Shown when the fix is low-accuracy (>200 m)
  ///
  /// In en, this message translates to:
  /// **'Your location is a bit rough right now — here\'s the rough direction. It\'ll sharpen as GPS settles.'**
  String get pointMeImprovingAccuracy;

  /// Shown when there is no location fix
  ///
  /// In en, this message translates to:
  /// **'Turn on location to point the way'**
  String get pointMeNeedsLocation;

  /// Unknown/removed venue id
  ///
  /// In en, this message translates to:
  /// **'We can\'t find that place'**
  String get pointMeUnknownPlace;

  /// Fallback bearing card
  ///
  /// In en, this message translates to:
  /// **'{venue} is about {distance} {cardinal} of you'**
  String pointMeBearingSentence(String venue, String distance, String cardinal);

  /// Live arrow semantic label
  ///
  /// In en, this message translates to:
  /// **'{venue} is {side}, {distance} away'**
  String pointMeA11yDirection(String venue, String side, String distance);

  /// No description provided for @sideAhead.
  ///
  /// In en, this message translates to:
  /// **'ahead of you'**
  String get sideAhead;

  /// No description provided for @sideBehind.
  ///
  /// In en, this message translates to:
  /// **'behind you'**
  String get sideBehind;

  /// No description provided for @sideLeft.
  ///
  /// In en, this message translates to:
  /// **'to your left'**
  String get sideLeft;

  /// No description provided for @sideRight.
  ///
  /// In en, this message translates to:
  /// **'to your right'**
  String get sideRight;

  /// No description provided for @cardinalN.
  ///
  /// In en, this message translates to:
  /// **'north'**
  String get cardinalN;

  /// No description provided for @cardinalNE.
  ///
  /// In en, this message translates to:
  /// **'north-east'**
  String get cardinalNE;

  /// No description provided for @cardinalE.
  ///
  /// In en, this message translates to:
  /// **'east'**
  String get cardinalE;

  /// No description provided for @cardinalSE.
  ///
  /// In en, this message translates to:
  /// **'south-east'**
  String get cardinalSE;

  /// No description provided for @cardinalS.
  ///
  /// In en, this message translates to:
  /// **'south'**
  String get cardinalS;

  /// No description provided for @cardinalSW.
  ///
  /// In en, this message translates to:
  /// **'south-west'**
  String get cardinalSW;

  /// No description provided for @cardinalW.
  ///
  /// In en, this message translates to:
  /// **'west'**
  String get cardinalW;

  /// No description provided for @cardinalNW.
  ///
  /// In en, this message translates to:
  /// **'north-west'**
  String get cardinalNW;

  /// CTA to open the embedded Google walking-nav screen
  ///
  /// In en, this message translates to:
  /// **'Navigate with Google Maps'**
  String get mapNavGoogle;

  /// Row hint for a place with no map coordinate (placeholder confidence or off the illustrated footprint); tapping still opens its details
  ///
  /// In en, this message translates to:
  /// **'Details only — not shown on the map'**
  String get mapPlaceListOnly;

  /// Route distance under 1 km
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String mapNavDistanceMeters(int meters);

  /// Route distance 1 km or more (km pre-formatted, one decimal)
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String mapNavDistanceKm(String km);

  /// Walking ETA under an hour
  ///
  /// In en, this message translates to:
  /// **'{mins} min'**
  String mapNavEtaMin(int mins);

  /// Walking ETA an hour or more
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {mins} min'**
  String mapNavEtaHourMin(int hours, int mins);

  /// 200 response with zero routes
  ///
  /// In en, this message translates to:
  /// **'No walking route found to here.'**
  String get mapNavNoRoute;

  /// Network failure fetching the route
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — can\'t fetch the route.'**
  String get mapNavOffline;

  /// API/malformed error fetching the route
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the route. Please try again.'**
  String get mapNavError;

  /// No location permission/fix for Google nav
  ///
  /// In en, this message translates to:
  /// **'Turn on location to get walking directions.'**
  String get mapNavNeedLocation;

  /// Shown on web/desktop, where google_maps_flutter has no implementation — NOT a missing-key problem
  ///
  /// In en, this message translates to:
  /// **'Walking directions with the live map work on the iPhone and Android apps. This build can’t show the Google map.'**
  String get mapNavPlatformUnsupported;

  /// Capability flag off (no keys) — deep-link landed here
  ///
  /// In en, this message translates to:
  /// **'Google Maps is not configured yet. Please add the Google Maps API key to enable directions.'**
  String get mapNavUnavailable;

  /// Live location is outside the campus scope — the in-app walking route is campus-only, so no route is generated
  ///
  /// In en, this message translates to:
  /// **'Walking directions are available once you are on campus.'**
  String get mapNavOffCampusOrigin;

  /// Requested destination falls outside the campus extent — defensive, curated places are always inside
  ///
  /// In en, this message translates to:
  /// **'This place isn\'t on the Astronomy Open Night campus map.'**
  String get mapNavDestinationOffCampus;

  /// Compact banner under a still-visible map when the Routes request fails
  ///
  /// In en, this message translates to:
  /// **'Walking route is temporarily unavailable. The map still shows your destination.'**
  String get mapNavRouteUnavailable;

  /// Strip under an already-visible map while the route request is in flight
  ///
  /// In en, this message translates to:
  /// **'Finding your walking route…'**
  String get mapNavFindingRoute;

  /// Retry a failed route fetch
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mapNavRetry;

  /// Header above Google-supplied route warnings
  ///
  /// In en, this message translates to:
  /// **'Route notices'**
  String get mapNavWarningsTitle;

  /// Header above the compact list of Google-supplied walking steps
  ///
  /// In en, this message translates to:
  /// **'Walking directions'**
  String get mapNavStepsTitle;

  /// Consent dialog title before sharing location with Google
  ///
  /// In en, this message translates to:
  /// **'Use Google Maps for directions?'**
  String get mapNavDisclosureTitle;

  /// Consent dialog body
  ///
  /// In en, this message translates to:
  /// **'To show a walking route, your current location is sent to Google Maps. Otherwise your location stays on your device and isn\'t shared.'**
  String get mapNavDisclosureBody;

  /// Consent accept button
  ///
  /// In en, this message translates to:
  /// **'Use Google Maps'**
  String get mapNavDisclosureAccept;

  /// Placeholder where the Google map would be, when consent was declined or the SDK is unkeyed.
  ///
  /// In en, this message translates to:
  /// **'Map not shown. The written directions below are complete on their own.'**
  String get wayfindingMapUnavailable;

  /// Disclosure body while preview mode is active, so the copy names what is actually transmitted.
  ///
  /// In en, this message translates to:
  /// **'To show a walking route, the simulated preview location — not your real position — is sent to Google Maps.'**
  String get mapNavDisclosureBodyPreview;

  /// Credits entry opening the Maps SDK open-source licence text.
  ///
  /// In en, this message translates to:
  /// **'Google Maps licences'**
  String get creditsMapsLicences;

  /// Persistent badge shown wherever a previewed (simulated) position is visualised, so it is never mistaken for a real fix.
  ///
  /// In en, this message translates to:
  /// **'Simulated location'**
  String get previewLocationBadge;

  /// Settings toggle that simulates an on-campus position.
  ///
  /// In en, this message translates to:
  /// **'Preview from anywhere'**
  String get settingsPreviewTitle;

  /// Explains that the previewed position is simulated.
  ///
  /// In en, this message translates to:
  /// **'Not on campus yet? Turn this on to see the map, compass and nearby list as they\'ll look on the night. The position shown is simulated, not your real location.'**
  String get settingsPreviewBody;

  /// Settings control that clears all locally stored app data.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get settingsEraseTitle;

  /// Explains the scope of the erase control.
  ///
  /// In en, this message translates to:
  /// **'Clears your saved plan, passport stamps, favourites and your Google Maps choice. Your language and theme settings are kept.'**
  String get settingsEraseBody;

  /// Destructive confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete data stored on this device?'**
  String get settingsEraseConfirmTitle;

  /// Destructive confirmation body. States the scope limit honestly.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes data stored by this app on this device. It cannot undo anything already sent to Google.'**
  String get settingsEraseConfirmBody;

  /// Destructive confirm button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsEraseConfirmAction;

  /// Dismisses the destructive confirmation.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsEraseCancel;

  /// Snackbar shown after a successful erase.
  ///
  /// In en, this message translates to:
  /// **'Deleted.'**
  String get settingsEraseDone;

  /// Shown when eraseAll returned false. Never claim a deletion that did not happen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your data. Please try again.'**
  String get settingsEraseFailed;

  /// Title of the map-only disclosure shown before wayfinding renders a Google basemap.
  ///
  /// In en, this message translates to:
  /// **'Load the Google map here?'**
  String get mapDisplayDisclosureTitle;

  /// Body of the map-only disclosure. States what THIS screen does, then what the same consent grant covers elsewhere, so accepting is informed for both.
  ///
  /// In en, this message translates to:
  /// **'This screen draws your walking route on a Google map. Google receives the map request and the technical request and device information it needs to serve it. This screen does not use your location.\n\nThe same choice also covers walking directions elsewhere in the app — if you ask for those, your location is sent to Google.'**
  String get mapDisplayDisclosureBody;

  /// Consent decline button
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get mapNavDisclosureDecline;

  /// Settings control to reset Google-nav consent to unknown
  ///
  /// In en, this message translates to:
  /// **'Revoke Google Maps access'**
  String get settingsRevokeGoogleConsent;

  /// No description provided for @settingsEnableGoogleConsent.
  ///
  /// In en, this message translates to:
  /// **'Turn Google Maps directions back on'**
  String get settingsEnableGoogleConsent;

  /// Settings/Info notice about Google Maps usage + ToS
  ///
  /// In en, this message translates to:
  /// **'When you use Google Maps directions, your location is sent to Google. Google\'s terms and privacy policy apply.'**
  String get settingsGoogleMapsNotice;

  /// Settings row that opens the hosted privacy policy in the browser
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// Shown when the privacy-policy link cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the privacy policy. Please try again.'**
  String get settingsPrivacyPolicyUnavailable;

  /// No description provided for @mapModeMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapModeMap;

  /// No description provided for @mapModePanorama.
  ///
  /// In en, this message translates to:
  /// **'360°'**
  String get mapModePanorama;

  /// No description provided for @mapModeCompass.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get mapModeCompass;

  /// No description provided for @compassFindingNorth.
  ///
  /// In en, this message translates to:
  /// **'Finding north…'**
  String get compassFindingNorth;

  /// No description provided for @compassFindingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get compassFindingYourLocation;

  /// No description provided for @compassUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Compass unavailable on this device'**
  String get compassUnavailable;

  /// No description provided for @compassUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Still showing each place\'s direction, north-up.'**
  String get compassUnavailableBody;

  /// No description provided for @compassNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get compassNearbyTitle;

  /// No description provided for @compassFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter places'**
  String get compassFilterHint;

  /// No description provided for @compassClusterLegend.
  ///
  /// In en, this message translates to:
  /// **'A number = how many places lie that way.'**
  String get compassClusterLegend;

  /// Accessible label for the un-aimed target row affordance
  ///
  /// In en, this message translates to:
  /// **'Point the compass here'**
  String get compassPointHere;

  /// Accessible label when a target row is the aimed compass target
  ///
  /// In en, this message translates to:
  /// **'Compass pointed here'**
  String get compassAimedHere;

  /// No description provided for @compassNothingNearby.
  ///
  /// In en, this message translates to:
  /// **'Nothing nearby to point to yet.'**
  String get compassNothingNearby;

  /// Collapsed section heading grouping venues the compass cannot point to
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place with no confirmed location} other{{count} places with no confirmed location}}'**
  String compassUnconfirmedHeading(int count);

  /// Explains the unconfirmed group so it does not read as broken
  ///
  /// In en, this message translates to:
  /// **'We don’t have a confirmed position for these, so the compass can’t point to them. Check the printed map or ask at an information point.'**
  String get compassUnconfirmedBlurb;

  /// Shown when every nearby place lacks a confirmed position
  ///
  /// In en, this message translates to:
  /// **'No confirmed locations to point to from here.'**
  String get compassNoConfirmedTargets;

  /// No description provided for @compassLocationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to find your way'**
  String get compassLocationNeeded;

  /// No description provided for @compassEnableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable location'**
  String get compassEnableLocation;

  /// No description provided for @compassYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'You\'re basically there'**
  String get compassYouAreHere;

  /// No description provided for @compassApproximate.
  ///
  /// In en, this message translates to:
  /// **'Approximate location'**
  String get compassApproximate;

  /// No description provided for @compassUnlocatable.
  ///
  /// In en, this message translates to:
  /// **'Location unknown — see the printed map'**
  String get compassUnlocatable;

  /// No description provided for @homeNothingRunningNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing running this minute — check what’s next.'**
  String get homeNothingRunningNow;

  /// No description provided for @homeFactColdTitle.
  ///
  /// In en, this message translates to:
  /// **'It gets cold and dark'**
  String get homeFactColdTitle;

  /// No description provided for @homeFactColdBody.
  ///
  /// In en, this message translates to:
  /// **'Bring a jacket and a torch. Red-light mode is best near the telescopes — it protects everyone’s night vision.'**
  String get homeFactColdBody;

  /// No description provided for @homeFactBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Some shows need pre-booking'**
  String get homeFactBookingTitle;

  /// No description provided for @homeFactBookingBody.
  ///
  /// In en, this message translates to:
  /// **'The magic shows and Destination Moon need seats booked at the time of ticket purchase.'**
  String get homeFactBookingBody;

  /// No description provided for @homeFactParkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Free parking'**
  String get homeFactParkingTitle;

  /// No description provided for @homeFactParkingBody.
  ///
  /// In en, this message translates to:
  /// **'West 5, West 6 and South 2.'**
  String get homeFactParkingBody;

  /// No description provided for @homeFactMetroTitle.
  ///
  /// In en, this message translates to:
  /// **'Metro'**
  String get homeFactMetroTitle;

  /// No description provided for @homeFactMetroBody.
  ///
  /// In en, this message translates to:
  /// **'Sydney Metro stops at Macquarie University Metro Station, on campus.'**
  String get homeFactMetroBody;

  /// No description provided for @programClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get programClearSearch;

  /// No description provided for @programBookedOnly.
  ///
  /// In en, this message translates to:
  /// **'Pre-booked only'**
  String get programBookedOnly;

  /// No description provided for @detailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get detailNotFoundTitle;

  /// No description provided for @detailSessionTimes.
  ///
  /// In en, this message translates to:
  /// **'Session times'**
  String get detailSessionTimes;

  /// No description provided for @detailTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get detailTime;

  /// No description provided for @detailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get detailLocation;

  /// No description provided for @detailUnpublishedTimes.
  ///
  /// In en, this message translates to:
  /// **'These times are not published in the official program — treat them as a guide.'**
  String get detailUnpublishedTimes;

  /// No description provided for @detailPositionUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The exact position of this location is still being confirmed. Follow signage and ask at an information point.'**
  String get detailPositionUnconfirmed;

  /// No description provided for @detail360View.
  ///
  /// In en, this message translates to:
  /// **'360° view'**
  String get detail360View;

  /// No description provided for @detailMarkedOnMap.
  ///
  /// In en, this message translates to:
  /// **'Marked {letter} on the printed event map'**
  String detailMarkedOnMap(String letter);

  /// No description provided for @myNightClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get myNightClearConfirm;

  /// No description provided for @settingsTextSizeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Set text size on your phone'**
  String get settingsTextSizeCardTitle;

  /// No description provided for @settingsPrivacyCardTitle.
  ///
  /// In en, this message translates to:
  /// **'What this app shares'**
  String get settingsPrivacyCardTitle;

  /// Settings credits: where the map data actually comes from now that walking directions use Google.
  ///
  /// In en, this message translates to:
  /// **'Campus map: Macquarie University. Walking directions and the map they appear on are provided by Google.'**
  String get settingsMapDataAttribution;

  /// No description provided for @infoFirstAid.
  ///
  /// In en, this message translates to:
  /// **'First aid'**
  String get infoFirstAid;

  /// No description provided for @infoToilets.
  ///
  /// In en, this message translates to:
  /// **'Toilets'**
  String get infoToilets;

  /// No description provided for @infoRegistrationAndInfo.
  ///
  /// In en, this message translates to:
  /// **'Registration and information'**
  String get infoRegistrationAndInfo;

  /// No description provided for @infoFoodAndDrink.
  ///
  /// In en, this message translates to:
  /// **'Food and drink'**
  String get infoFoodAndDrink;

  /// No description provided for @infoParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get infoParking;

  /// No description provided for @infoParkingFree.
  ///
  /// In en, this message translates to:
  /// **'Free event parking'**
  String get infoParkingFree;

  /// No description provided for @infoWalkingFromParking.
  ///
  /// In en, this message translates to:
  /// **'Walking directions from parking'**
  String get infoWalkingFromParking;

  /// No description provided for @infoGettingHere.
  ///
  /// In en, this message translates to:
  /// **'Getting here'**
  String get infoGettingHere;

  /// No description provided for @infoBeforeYouCome.
  ///
  /// In en, this message translates to:
  /// **'Before you come'**
  String get infoBeforeYouCome;

  /// No description provided for @infoDressTitle.
  ///
  /// In en, this message translates to:
  /// **'Dress for standing outside'**
  String get infoDressTitle;

  /// No description provided for @infoDressBody.
  ///
  /// In en, this message translates to:
  /// **'The Telescope Park and the Central Courtyard are open ground, and September evenings get cold. Bring a jacket.'**
  String get infoDressBody;

  /// No description provided for @infoTorchTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring a torch — red light if you have it'**
  String get infoTorchTitle;

  /// No description provided for @infoTorchBody.
  ///
  /// In en, this message translates to:
  /// **'It gets genuinely dark towards the Observatory, and that is on purpose. White light ruins night vision for everyone around you, so use a red torch mode near the telescopes and turn your phone brightness down.'**
  String get infoTorchBody;

  /// No description provided for @infoBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Book the ticketed shows early'**
  String get infoBookTitle;

  /// No description provided for @infoBookBody.
  ///
  /// In en, this message translates to:
  /// **'The physics and chemistry magic shows and Destination Moon need seats pre-booked at the time of ticket purchase.'**
  String get infoBookBody;

  /// No description provided for @infoChildrenTitle.
  ///
  /// In en, this message translates to:
  /// **'Children must be supervised'**
  String get infoChildrenTitle;

  /// No description provided for @infoChildrenBody.
  ///
  /// In en, this message translates to:
  /// **'Children must be accompanied by a parent or guardian at all times in the Kids’ space.'**
  String get infoChildrenBody;

  /// No description provided for @infoCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'If it clouds over'**
  String get infoCloudTitle;

  /// No description provided for @infoCloudBody.
  ///
  /// In en, this message translates to:
  /// **'Telescope viewing depends on the weather, but the planetarium sessions at the Sport and Aquatic Centre run regardless.'**
  String get infoCloudBody;

  /// No description provided for @infoCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get infoCredits;

  /// No description provided for @previewSection.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewSection;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview event night'**
  String get previewTitle;

  /// No description provided for @previewBody.
  ///
  /// In en, this message translates to:
  /// **'Set the app’s clock to any point on {date} to see what the program looks like at that moment. Useful before the night; leave it off during the event.'**
  String previewBody(String date);

  /// No description provided for @previewChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a time'**
  String get previewChooseTime;

  /// No description provided for @previewBackToRealTime.
  ///
  /// In en, this message translates to:
  /// **'Back to real time'**
  String get previewBackToRealTime;

  /// No description provided for @previewBanner.
  ///
  /// In en, this message translates to:
  /// **'Previewing {time} on event night'**
  String previewBanner(String time);

  /// No description provided for @previewExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get previewExit;

  /// Entry-point label for the Astronomy Passport feature (owned by the map/backend side). NOTE: not present in the official programme PDF — pending confirmation with Liz.
  ///
  /// In en, this message translates to:
  /// **'Astronomy Passport'**
  String get passportTitle;

  /// No description provided for @venueNoDirections.
  ///
  /// In en, this message translates to:
  /// **'We don’t have written walking directions to here yet. Ask at an information point in the Central Courtyard.'**
  String get venueNoDirections;

  /// No description provided for @venueNothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled here tonight.'**
  String get venueNothingScheduled;

  /// No description provided for @parkingNoConfirmedPosition.
  ///
  /// In en, this message translates to:
  /// **'We don’t have a confirmed position for this car park yet — follow on-site signage.'**
  String get parkingNoConfirmedPosition;

  /// No description provided for @creditsEventMaterialsBody.
  ///
  /// In en, this message translates to:
  /// **'Event materials and branding © {host}, {faculty}. {cricos}.'**
  String creditsEventMaterialsBody(String host, String faculty, String cricos);

  /// No description provided for @creditsHeroImageBody.
  ///
  /// In en, this message translates to:
  /// **'Hero image: “{credit}”. Used with permission for this project.'**
  String creditsHeroImageBody(String credit);

  /// Clears both wayfinding endpoints.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get wayfindingReset;

  /// Both endpoints chosen but no authored route joins them.
  ///
  /// In en, this message translates to:
  /// **'No directions for that pair yet'**
  String get wayfindingNoPairTitle;

  /// Body for the no-route-for-this-pair empty state.
  ///
  /// In en, this message translates to:
  /// **'We don’t have a written route between those two points. Try the Central Courtyard as a staging point — most routes run through it — or ask at an information point.'**
  String get wayfindingNoPairBody;

  /// Confidence note shown on every placeholder-confidence route.
  ///
  /// In en, this message translates to:
  /// **'These directions are a draft and have not yet been walked and verified on campus at night. Follow event signage and marshals if they differ.'**
  String get wayfindingDraftRoute;

  /// Route is known to be step-free.
  ///
  /// In en, this message translates to:
  /// **'Step-free access along this route.'**
  String get wayfindingStepFree;

  /// Route is known NOT to be step-free.
  ///
  /// In en, this message translates to:
  /// **'This route is not step-free.'**
  String get wayfindingNotStepFree;

  /// Explains the System option — the app ships English and Persian only, so most devices land on English.
  ///
  /// In en, this message translates to:
  /// **'Falls back to English if your device language isn’t available.'**
  String get settingsLanguageSystemHint;

  /// The English option. Always written in English — a language name must be legible to someone who does not yet read the current language.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// The Persian-language option, labelled in English ('Persian', not the 'Farsi' endonym) so an English reader recognises it. The Persian-locale ARB keeps the فارسی endonym.
  ///
  /// In en, this message translates to:
  /// **'Persian'**
  String get settingsLanguagePersian;

  /// Map/navigation attribution: the illustrated campus map is Macquarie University; walking directions and their basemap come from Google.
  ///
  /// In en, this message translates to:
  /// **'Campus map: Macquarie University. Walking directions and the map they appear on are provided by Google.'**
  String get creditsMapDataBody;

  /// Provenance line under an activity — which published document this entry came from.
  ///
  /// In en, this message translates to:
  /// **'Source: {note}'**
  String eventSourceNote(String note);

  /// Cross-reference to the paper map handed out on the night.
  ///
  /// In en, this message translates to:
  /// **'Marked {ref} on the printed event map'**
  String eventMapReference(String ref);

  /// Timing label for an activity that has not started, shown when today is NOT the event date. Replaces 'Later tonight', which would falsely imply the event is today.
  ///
  /// In en, this message translates to:
  /// **'On the night'**
  String get timingOnTheNight;

  /// Programme section: drop-in, hands-on activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get categoryActivities;

  /// Programme section: the 12 short research talks.
  ///
  /// In en, this message translates to:
  /// **'Short talks'**
  String get categoryShortTalks;

  /// Programme section: the single keynote.
  ///
  /// In en, this message translates to:
  /// **'Keynote lecture'**
  String get categoryKeynote;

  /// Programme section: the longer featured talks.
  ///
  /// In en, this message translates to:
  /// **'Featured presentations'**
  String get categoryFeaturedPresentations;

  /// Time filter for the first two hours of the event.
  ///
  /// In en, this message translates to:
  /// **'4–6pm'**
  String get bandEarlyEvening;

  /// Time filter for the middle two hours.
  ///
  /// In en, this message translates to:
  /// **'6–8pm'**
  String get bandEvening;

  /// Time filter for the final two hours.
  ///
  /// In en, this message translates to:
  /// **'8–10pm'**
  String get bandLateEvening;

  /// Bottom-nav label for the Settings tab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Developer attribution. {first}/{second} are people’s names — proper nouns, never translated.
  ///
  /// In en, this message translates to:
  /// **'Developed by {first} and {second}'**
  String creditsDevelopedBy(String first, String second);

  /// Settings toggle: whether tactile controls vibrate.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get settingsHaptics;

  /// Explains the haptics toggle.
  ///
  /// In en, this message translates to:
  /// **'A gentle vibration when you tap buttons and save activities. Turn it off if you prefer no vibration.'**
  String get settingsHapticsBody;

  /// Credits sub-heading above the two developer names.
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get settingsCreditsDevelopers;

  /// Credits caption acknowledging the app was built by two MQ student developers for the AON team. An appreciation, NOT a claim of official University ownership.
  ///
  /// In en, this message translates to:
  /// **'Two Macquarie University student app developers, in appreciation of the Astronomy Open Night team.'**
  String get creditsAcknowledgement;

  /// Settings section header for the delete-my-data control.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsYourData;

  /// Astronomy Passport progress: how many stamps collected out of the total. count=collected, total=all stations.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} stamps'**
  String passportStampProgress(int count, int total);

  /// Settings card title for the passport preview switch.
  ///
  /// In en, this message translates to:
  /// **'Preview the Astronomy Passport'**
  String get settingsPassportPreviewTitle;

  /// Explains what the passport preview switch does now that the station codes are live: it only adds a preview badge; stamps are stored like real ones. Must not claim the codes are unconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The station codes are live, so stamps can be collected on any build. Turn this on only to practise the rally away from the venue signs — a preview badge shows while it\'s on. Practice stamps stay on this device like real ones; clear them with Delete my data.'**
  String get settingsPassportPreviewBody;

  /// Badge shown on the passport whenever preview collection is engaged, so a practice stamp is never mistaken for a real one.
  ///
  /// In en, this message translates to:
  /// **'Preview stamps'**
  String get passportPreviewBadge;

  /// Passport progress line.
  ///
  /// In en, this message translates to:
  /// **'{count} / {total} stamps'**
  String passportProgress(int count, int total);

  /// Shown when collection is gated and preview is off.
  ///
  /// In en, this message translates to:
  /// **'Astronomy Passport opens on event night'**
  String get passportOpensOnEventNight;

  /// Progress line at zero stamps.
  ///
  /// In en, this message translates to:
  /// **'Scan or enter a venue code to start'**
  String get passportStartHint;

  /// Progress line with exactly one station left.
  ///
  /// In en, this message translates to:
  /// **'Just 1 more to go!'**
  String get passportOneMoreToGo;

  /// Non-blocking note after a persistence write failed.
  ///
  /// In en, this message translates to:
  /// **'Your progress may not be saved on this device.'**
  String get passportSaveFailed;

  /// Button shown once the passport is complete.
  ///
  /// In en, this message translates to:
  /// **'View your reward'**
  String get passportViewReward;

  /// Primary button opening the capture screen.
  ///
  /// In en, this message translates to:
  /// **'Scan or enter a code'**
  String get passportScanOrEnter;

  /// Confirm dialog title for clearing stamps.
  ///
  /// In en, this message translates to:
  /// **'Reset passport?'**
  String get passportResetTitle;

  /// Confirm dialog body for clearing stamps.
  ///
  /// In en, this message translates to:
  /// **'This clears all collected stamps on this device.'**
  String get passportResetBody;

  /// Confirm action for clearing stamps.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get passportResetConfirm;

  /// App bar title of the capture screen.
  ///
  /// In en, this message translates to:
  /// **'Collect a stamp'**
  String get passportScanTitle;

  /// Outcome: a new stamp was captured.
  ///
  /// In en, this message translates to:
  /// **'Stamp collected!'**
  String get passportScanCollected;

  /// Outcome: this station was already stamped.
  ///
  /// In en, this message translates to:
  /// **'You already have this one.'**
  String get passportScanAlready;

  /// Outcome: the code is foreign to this event.
  ///
  /// In en, this message translates to:
  /// **'That\'s not an Astronomy Open Night code.'**
  String get passportScanUnknown;

  /// Outcome: collection is gated and preview is off.
  ///
  /// In en, this message translates to:
  /// **'The passport isn\'t live yet — see staff at an information point.'**
  String get passportScanDisabled;

  /// Opens the camera scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get passportScanQrButton;

  /// Reveals the manual code field.
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get passportEnterCodeButton;

  /// Instruction above the manual code field.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the venue sign'**
  String get passportEnterCodeHint;

  /// Label of the manual code text field.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get passportCodeLabel;

  /// Submits a manually typed code.
  ///
  /// In en, this message translates to:
  /// **'Add stamp'**
  String get passportAddStamp;

  /// Returns to the capture options after an outcome.
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get passportScanAnother;

  /// Search-sheet action card shown when a visitor searches for parking.
  ///
  /// In en, this message translates to:
  /// **'Parking & walking routes'**
  String get mapSearchParkingTitle;

  /// Body of the parking search action card.
  ///
  /// In en, this message translates to:
  /// **'West 5, West 6 and South 2 — get walking directions to and from the Central Courtyard.'**
  String get mapSearchParkingBody;

  /// Primary button that opens Google Maps walking directions to a place.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get mapDirections;

  /// Venue category: a place where activities run.
  ///
  /// In en, this message translates to:
  /// **'Event venue'**
  String get venueCatEventVenue;

  /// Venue category: a staffed information point.
  ///
  /// In en, this message translates to:
  /// **'Information point'**
  String get venueCatInformationPoint;

  /// Venue category: the registration desk.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get venueCatRegistration;

  /// Venue category: toilets.
  ///
  /// In en, this message translates to:
  /// **'Toilets'**
  String get venueCatToilets;

  /// Venue category: the first-aid post.
  ///
  /// In en, this message translates to:
  /// **'First aid'**
  String get venueCatFirstAid;

  /// Venue category: food and drink.
  ///
  /// In en, this message translates to:
  /// **'Food and drink'**
  String get venueCatFoodAndDrink;

  /// Venue category: a car park.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get venueCatParking;

  /// Venue category: the Sydney Metro station.
  ///
  /// In en, this message translates to:
  /// **'Metro station'**
  String get venueCatMetro;

  /// Venue category: anything uncategorised.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get venueCatOther;

  /// Countdown when a session starts within the minute.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeRelativeNow;

  /// Countdown to a session start, e.g. 'in 12 min'.
  ///
  /// In en, this message translates to:
  /// **'in {duration}'**
  String timeRelativeIn(String duration);

  /// A session whose end time has passed.
  ///
  /// In en, this message translates to:
  /// **'ended'**
  String get timeRelativeEnded;

  /// A session with under a minute left.
  ///
  /// In en, this message translates to:
  /// **'ending now'**
  String get timeRelativeEndingNow;

  /// A whole number of hours, with no minutes remainder.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr'**
  String timeDurationHours(int hours);

  /// Joins the last item of a list, e.g. 'A, B and C'.
  ///
  /// In en, this message translates to:
  /// **'{items} and {last}'**
  String listAnd(String items, String last);

  /// Shown when /passport/reward is opened before all stamps are collected.
  ///
  /// In en, this message translates to:
  /// **'Your passport is not complete yet — keep collecting stamps.'**
  String get passportRewardIncomplete;

  /// App-bar title of the completed passport reward screen.
  ///
  /// In en, this message translates to:
  /// **'Passport complete'**
  String get passportRewardCompleteTitle;

  /// Celebration headline on the reward screen.
  ///
  /// In en, this message translates to:
  /// **'All {total} stamps collected!'**
  String passportRewardAllCollected(int total);

  /// Redemption instruction on the reward screen.
  ///
  /// In en, this message translates to:
  /// **'Show this to staff at the prize booth.'**
  String get passportRewardShowStaff;

  /// Shown instead of the camera on the web build.
  ///
  /// In en, this message translates to:
  /// **'Scanning isn\'t available on the web — enter the code below.'**
  String get passportScanWebUnavailable;

  /// Shown when the camera cannot start (permission denied or no camera).
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable — enter the code from the sign instead.'**
  String get passportScanCameraUnavailable;

  /// Button that toggles the camera torch while scanning.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get passportScanTorch;

  /// Accessible name of a collected passport cell.
  ///
  /// In en, this message translates to:
  /// **'{name}, stamp collected'**
  String passportCellCollected(String name);

  /// Accessible name of an uncollected passport cell.
  ///
  /// In en, this message translates to:
  /// **'{name}, not yet collected'**
  String passportCellNotCollected(String name);

  /// Accessibility hint on a collected, tappable passport cell.
  ///
  /// In en, this message translates to:
  /// **'Opens astronomy fact'**
  String get passportCellOpensFact;

  /// Confidence note on a placeholder astronomy fact.
  ///
  /// In en, this message translates to:
  /// **'Draft — awaiting review by the astronomy team.'**
  String get passportFactDraftNote;

  /// Generic button that dismisses a sheet or dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Subtitle of a picker card for a venue with no 360° imagery yet.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get panoramaComingSoon;

  /// Disclosure shown on a placeholder tour so sample imagery cannot pass as the real venue.
  ///
  /// In en, this message translates to:
  /// **'Demo 360° — sample imagery, not this venue'**
  String get panoramaDemoFlag;

  /// Shown when the 360° viewer cannot load.
  ///
  /// In en, this message translates to:
  /// **'360° preview unavailable'**
  String get panoramaPreviewUnavailable;

  /// Accessible name of a picker card with no tour.
  ///
  /// In en, this message translates to:
  /// **'{name}, coming soon'**
  String panoramaCardComingSoon(String name);

  /// Accessible name of a picker card with a real tour.
  ///
  /// In en, this message translates to:
  /// **'{name}, 360 tour'**
  String panoramaCardTour(String name);

  /// Accessible name of a picker card with a placeholder tour.
  ///
  /// In en, this message translates to:
  /// **'{name}, demo 360 tour'**
  String panoramaCardDemoTour(String name);
}

class _AonL10nDelegate extends LocalizationsDelegate<AonL10n> {
  const _AonL10nDelegate();

  @override
  Future<AonL10n> load(Locale locale) {
    return SynchronousFuture<AonL10n>(lookupAonL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AonL10nDelegate old) => false;
}

AonL10n lookupAonL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AonL10nEn();
    case 'fa':
      return AonL10nFa();
  }

  throw FlutterError(
    'AonL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
