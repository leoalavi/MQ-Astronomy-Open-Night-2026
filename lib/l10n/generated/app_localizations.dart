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

  /// No description provided for @timingOpenAllEvening.
  ///
  /// In en, this message translates to:
  /// **'Open all evening'**
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
  /// **'Venues, toilets, first aid — and walking directions from the car parks'**
  String get homeOpenMapBody;

  /// No description provided for @homeOpenMapBodyNoWayfinding.
  ///
  /// In en, this message translates to:
  /// **'Venues, toilets, first aid and parking'**
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

  /// No description provided for @quickAccessWalkingRoutes.
  ///
  /// In en, this message translates to:
  /// **'Walking routes'**
  String get quickAccessWalkingRoutes;

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

  /// No description provided for @programItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items in the program'**
  String programItemCount(int count);

  /// No description provided for @programFilteredCount.
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

  /// No description provided for @mapAttribution.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

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

  /// Title of the thematic-variant picker sheet; label of the Layers button
  ///
  /// In en, this message translates to:
  /// **'Map layers'**
  String get mapLayersTitle;

  /// Picker row for the plain illustrated campus basemap (no theme)
  ///
  /// In en, this message translates to:
  /// **'Campus map'**
  String get mapVariantBase;

  /// No description provided for @mapVariantParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get mapVariantParking;

  /// No description provided for @mapVariantParkingDesc.
  ///
  /// In en, this message translates to:
  /// **'Visitor and event parking areas'**
  String get mapVariantParkingDesc;

  /// No description provided for @mapVariantAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessible routes'**
  String get mapVariantAccessibility;

  /// No description provided for @mapVariantAccessibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Step-free paths and accessible entrances'**
  String get mapVariantAccessibilityDesc;

  /// No description provided for @mapVariantWater.
  ///
  /// In en, this message translates to:
  /// **'Drinking water'**
  String get mapVariantWater;

  /// No description provided for @mapVariantWaterDesc.
  ///
  /// In en, this message translates to:
  /// **'Water refill points across campus'**
  String get mapVariantWaterDesc;

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

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow my phone'**
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
  /// **'Nothing leaves your phone'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'There is no account and no sign-in. Your saved activities are stored on this device only. The app collects no analytics and tracks no location.\n\nThe only thing it fetches from the internet is map imagery.'**
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

  /// No description provided for @wayfindingStartingFrom.
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get wayfindingStartingFrom;

  /// No description provided for @wayfindingGoingTo.
  ///
  /// In en, this message translates to:
  /// **'Going to'**
  String get wayfindingGoingTo;

  /// No description provided for @wayfindingPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a start and a destination'**
  String get wayfindingPickTitle;

  /// No description provided for @wayfindingPickBody.
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

  /// No description provided for @wayfindingDirections.
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

  /// No description provided for @wayfindingStepFreeUnknown.
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
