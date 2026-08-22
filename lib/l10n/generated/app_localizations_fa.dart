// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AonL10nFa extends AonL10n {
  AonL10nFa([String locale = 'fa']) : super(locale);

  @override
  String get eventName => 'شب باز نجوم';

  @override
  String get tabHome => 'خانه';

  @override
  String get tabProgram => 'برنامه';

  @override
  String get tabMyNight => 'شب من';

  @override
  String get tabMap => 'نقشه';

  @override
  String get tabInfo => 'اطلاعات';

  @override
  String get myNight => 'شب من';

  @override
  String get myNightEmptyTitle => 'شب شما خالی است';

  @override
  String get myNightEmptyBody =>
      'برای برنامه‌ریزی شبتان، ستارهٔ کنار هر فعالیت را بزنید. همه را به ترتیب زمان می‌چینیم و می‌گوییم کجا بروید.';

  @override
  String myNightNext(String planName) {
    return 'بعدی در $planName';
  }

  @override
  String myNightSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فعالیت ذخیره شد',
      one: '۱ فعالیت ذخیره شد',
    );
    return '$_temp0';
  }

  @override
  String myNightSessionOf(int index, int total) {
    return 'سانس $index از $total';
  }

  @override
  String myNightClearTitle(String planName) {
    return '$planName پاک شود؟';
  }

  @override
  String get myNightClearBody =>
      'همهٔ فعالیت‌های ذخیره‌شده حذف می‌شوند. این کار برگشت‌پذیر نیست.';

  @override
  String get myNightAllFinished =>
      'همهٔ چیزهایی که ذخیره کرده بودید تمام شد. چه شبی!';

  @override
  String get myNightConflictBanner =>
      'بعضی از فعالیت‌های ذخیره‌شدهٔ شما هم‌زمان‌اند. در ادامه علامت‌گذاری شده‌اند — بیشترشان بیش از یک بار برگزار می‌شوند، پس سانس دیگری را بررسی کنید.';

  @override
  String myNightConflictOverlaps(String titles) {
    return 'هم‌زمان با $titles';
  }

  @override
  String get myNightLoadFailedTitle => 'برنامهٔ ذخیره‌شدهٔ شما باز نشد';

  @override
  String get myNightLoadFailedBody =>
      'فعالیت‌های ذخیره‌شدهٔ شما روی همین دستگاه نگهداری می‌شوند. کمی بعد دوباره تلاش کنید.';

  @override
  String get timingHappeningNow => 'هم‌اکنون در حال اجرا';

  @override
  String get timingStartingSoon => 'به‌زودی شروع می‌شود';

  @override
  String get timingLaterTonight => 'بعدتر امشب';

  @override
  String get timingFinished => 'پایان‌یافته';

  @override
  String get timingOpenAllEvening => 'تمام شب باز است';

  @override
  String timingStartingWithin(int minutes) {
    return 'در $minutes دقیقهٔ آینده';
  }

  @override
  String get phaseTonight => 'امشب';

  @override
  String get phaseStartsSoon => 'به‌زودی آغاز می‌شود';

  @override
  String get phaseHappeningNow => 'هم‌اکنون در حال اجرا';

  @override
  String get phaseEndingSoon => 'رو به پایان';

  @override
  String get phaseEnded => 'این رویداد به پایان رسیده است';

  @override
  String get homeUpNext => 'بعدی';

  @override
  String get homeNothingRightNow =>
      'در این لحظه چیزی در حال اجرا نیست — برنامهٔ بعدی را ببینید.';

  @override
  String homeSeeWholeEvent(String period) {
    return 'دیدن کل $period';
  }

  @override
  String get homeOpenMapTitle => 'باز کردن نقشهٔ پردیس';

  @override
  String get homeOpenMapBody =>
      'مکان‌ها، سرویس بهداشتی، کمک‌های اولیه — و مسیر پیاده از پارکینگ‌ها';

  @override
  String get homeOpenMapBodyNoWayfinding =>
      'مکان‌ها، سرویس بهداشتی، کمک‌های اولیه و پارکینگ';

  @override
  String get homeQuickAccessTitle => 'مسیر رسیدن به';

  @override
  String get homeGoodToKnow => 'خوب است بدانید';

  @override
  String get homeImageCredit => 'اعتبار تصویر';

  @override
  String get quickAccessTelescopes => 'تلسکوپ‌ها';

  @override
  String get quickAccessPlanetariums => 'آسمان‌نماها';

  @override
  String get quickAccessTalks => 'سخنرانی‌ها';

  @override
  String get quickAccessKids => 'فعالیت‌های کودکان';

  @override
  String get quickAccessFood => 'خوراکی و نوشیدنی';

  @override
  String get quickAccessToilets => 'سرویس بهداشتی';

  @override
  String get quickAccessFirstAid => 'کمک‌های اولیه';

  @override
  String get quickAccessParking => 'پارکینگ';

  @override
  String get quickAccessWalkingRoutes => 'مسیرهای پیاده';

  @override
  String get programTonight => 'امشب';

  @override
  String get programSections => 'بخش‌ها';

  @override
  String get programSearchHint => 'جست‌وجوی سخنرانی، فعالیت یا سخنران';

  @override
  String programItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString برنامه',
      one: '۱ برنامه',
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

    return 'نمایش $shownString از $totalString';
  }

  @override
  String get programNoMatchTitle => 'چیزی پیدا نشد';

  @override
  String get programNoMatchBody =>
      'یکی از فیلترها را بردارید یا عبارت دیگری را جست‌وجو کنید.';

  @override
  String get programClearFilters => 'پاک کردن فیلترها';

  @override
  String get programPreBookingRequired => 'نیازمند رزرو پیشین';

  @override
  String get actionSave => 'ذخیره';

  @override
  String get actionSaved => 'ذخیره شد';

  @override
  String get actionClear => 'پاک کردن';

  @override
  String get actionCancel => 'انصراف';

  @override
  String get actionUndo => 'بازگردانی';

  @override
  String get actionRetry => 'تلاش دوباره';

  @override
  String get actionWalkThere => 'مسیر پیاده';

  @override
  String get actionShowOnMap => 'نمایش روی نقشه';

  @override
  String get actionBrowseProgram => 'مرور برنامه';

  @override
  String get actionRemoveFromPlan => 'حذف از برنامه';

  @override
  String get actionBack => 'بازگشت';

  @override
  String a11ySaveToPlan(String title, String planName) {
    return 'ذخیرهٔ $title در $planName';
  }

  @override
  String a11yRemoveFromPlan(String title, String planName) {
    return 'حذف $title از $planName';
  }

  @override
  String snackSavedTo(String planName) {
    return 'در $planName ذخیره شد';
  }

  @override
  String snackRemovedFrom(String planName) {
    return 'از $planName حذف شد';
  }

  @override
  String get mapTitle => 'نقشه';

  @override
  String get mapWalkingDirections => 'مسیر پیاده';

  @override
  String get mapLookInside360 => 'نمای ۳۶۰ درجه از داخل';

  @override
  String get mapOnHereTonight => 'امشب در این مکان';

  @override
  String get mapAttributionCampus => 'نقشهٔ پردیس: دانشگاه مکواری';

  @override
  String get mapRecentre => 'بازگشت به مرکز';

  @override
  String get mapZoomIn => 'بزرگ‌نمایی';

  @override
  String get mapZoomOut => 'کوچک‌نمایی';

  @override
  String get mapSearchTitle => 'یافتن مکان';

  @override
  String get mapSearchHint => 'جست‌وجوی ساختمان‌ها و مکان‌ها';

  @override
  String get mapSearchTooltip => 'جست‌وجو';

  @override
  String mapSearchEmpty(String query) {
    return 'نتیجه‌ای برای «$query» یافت نشد';
  }

  @override
  String get mapFavoritesTitle => 'علاقه‌مندی‌ها';

  @override
  String get mapFavoritesTooltip => 'علاقه‌مندی‌ها';

  @override
  String get mapFavoritesEmpty => 'هنوز علاقه‌مندی‌ای ندارید';

  @override
  String get mapFavoritesLoading => 'در حال بارگذاری…';

  @override
  String get mapFavoriteUnavailable => 'در دسترس نیست';

  @override
  String get mapFavoriteAdd => 'افزودن به علاقه‌مندی‌ها';

  @override
  String get mapFavoriteRemove => 'حذف از علاقه‌مندی‌ها';

  @override
  String mapBuildingGridRef(String ref) {
    return 'شبکهٔ $ref';
  }

  @override
  String get mapCatAcademic => 'آموزشی';

  @override
  String get mapCatServices => 'خدمات';

  @override
  String get mapCatHealth => 'بهداشت و درمان';

  @override
  String get mapCatFood => 'غذا و نوشیدنی';

  @override
  String get mapCatSports => 'ورزشی';

  @override
  String get mapCatVenue => 'سالن رویداد';

  @override
  String get mapCatResearch => 'پژوهشی';

  @override
  String get mapCatResidential => 'مسکونی';

  @override
  String get mapCatParking => 'پارکینگ';

  @override
  String get mapCatTransport => 'حمل‌ونقل';

  @override
  String get mapCatSmoking => 'محل سیگار';

  @override
  String get mapCatTeaching => 'تدریس';

  @override
  String get mapCatOther => 'دیگر';

  @override
  String get panorama360Unavailable =>
      'نمای سه‌بعدی برای این مکان در دسترس نیست.';

  @override
  String get panorama360Loading => 'در حال بارگذاری نمای ۳۶۰ درجه…';

  @override
  String get panorama360Title => 'پیش‌نمای ۳۶۰ درجه';

  @override
  String get settingsTitle => 'تنظیمات';

  @override
  String get settingsAppearance => 'ظاهر';

  @override
  String get settingsAppearanceSystem => 'مطابق تنظیمات گوشی';

  @override
  String get settingsAppearanceLight => 'روشن';

  @override
  String get settingsAppearanceDark => 'تیره';

  @override
  String get settingsAppearanceDarkHint =>
      'پیشنهادی — در رویداد برای دید شبانه‌تان بهتر است';

  @override
  String get settingsMotion => 'حرکت';

  @override
  String get settingsReduceMotion => 'کاهش حرکت';

  @override
  String get settingsReduceMotionBody =>
      'انیمیشن نوار پایین و سطوح شیشه‌ای را خاموش می‌کند. تنظیم «کاهش حرکت» خودِ گوشی همیشه رعایت می‌شود.';

  @override
  String get settingsTextSize => 'اندازهٔ متن';

  @override
  String get settingsTextSizeTitle => 'اندازهٔ متن را در گوشی خود تنظیم کنید';

  @override
  String settingsTextSizeBody(int percent) {
    return 'این برنامه از اندازهٔ متن دستگاه شما تا $percent٪ پیروی می‌کند و همهٔ صفحه‌ها در آن اندازه آزموده شده‌اند. آن را در تنظیمات نمایش یا دسترس‌پذیری گوشی تغییر دهید.';
  }

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsLanguageSystem => 'هم‌سان با دستگاه';

  @override
  String settingsAbout(String eventName) {
    return 'دربارهٔ $eventName';
  }

  @override
  String get settingsPrivacy => 'حریم خصوصی';

  @override
  String get settingsPrivacyTitle => 'این برنامه چه چیزی را به اشتراک می‌گذارد';

  @override
  String get settingsPrivacyBody =>
      'نه حسابی وجود دارد و نه ورودی. مهرهای پاسپورت، علاقه‌مندی‌ها و برنامهٔ ذخیره‌شدهٔ شما روی همین دستگاه می‌مانند. این برنامه هیچ دادهٔ تحلیلی جمع نمی‌کند.\n\nدوربین فقط برای خواندن کد QR استفاده می‌شود و تصویر آن هرگز ذخیره یا ارسال نمی‌شود.\n\nموقعیت مکانی شما روی همین دستگاه برای نمایش جایگاه شما روی نقشهٔ پردیس به کار می‌رود. تنها زمانی به گوگل ارسال می‌شود که خودتان مسیریابی پیاده بخواهید — و تنها پس از موافقت شما.\n\nمسیریاب، مسیر را روی نقشهٔ گوگل رسم می‌کند. بارگذاری هر نقشهٔ گوگل، درخواست نقشه به‌همراه اطلاعات فنی درخواست و دستگاه لازم برای ارائهٔ آن را به گوگل می‌فرستد — اما موقعیت مکانی شما را نه.';

  @override
  String get settingsCredits => 'اعتبارها';

  @override
  String get settingsCreditsHeroImage => 'تصویر اصلی';

  @override
  String get settingsCreditsEventMaterials => 'مواد رویداد';

  @override
  String get settingsCreditsMapData => 'داده‌های نقشه';

  @override
  String get settingsUnavailableTitle => 'تنظیمات در دسترس نیست';

  @override
  String get settingsUnavailableBody =>
      'تنظیمات شما روی این دستگاه باز نشد. برنامه کار می‌کند، فقط این انتخاب را به خاطر نمی‌سپارد.';

  @override
  String get infoTitle => 'اطلاعات کاربردی';

  @override
  String get infoLocationToBeConfirmed => 'مکان هنوز نهایی نشده است';

  @override
  String get infoDetailToBeConfirmed => 'این مورد هنوز تأیید نشده است.';

  @override
  String get eventNotFoundTitle => 'این فعالیت پیدا نشد';

  @override
  String get eventNotFoundBody =>
      'ممکن است پس از هم‌رسانی این پیوند، در برنامه تغییر کرده یا حذف شده باشد.';

  @override
  String get wayfindingTitle => 'مسیر پیاده';

  @override
  String get wayfindingStartingFrom => 'نقطهٔ شروع';

  @override
  String get wayfindingGoingTo => 'مقصد';

  @override
  String get wayfindingPickTitle => 'یک نقطهٔ شروع و یک مقصد انتخاب کنید';

  @override
  String get wayfindingPickBody =>
      'انتخاب کنید کجا پارک کرده‌اید و به کجا می‌روید، تا راهنمای نوشتاری پیمودن آن در تاریکی را به شما بدهیم.';

  @override
  String get wayfindingNoRouteTitle => 'هنوز مسیری برای این دو نقطه نداریم';

  @override
  String get wayfindingNoRouteBody =>
      'میان این دو نقطه مسیر نوشتاری نداریم. حیاط مرکزی را به‌عنوان نقطهٔ میانی امتحان کنید — بیشتر مسیرها از آنجا می‌گذرند — یا از باجهٔ اطلاعات بپرسید.';

  @override
  String get wayfindingDirections => 'راهنمای مسیر';

  @override
  String get wayfindingStraightLineNote =>
      'خط مستقیم نشان داده شده است — این جهت کلی است، نه مسیر دقیق. راهنمای نوشتاری زیر را دنبال کنید.';

  @override
  String get wayfindingDraftWarning =>
      'این راهنما پیش‌نویس است و هنوز شبانه در پردیس پیموده و تأیید نشده است. اگر با تابلوها یا راهنمایان رویداد تفاوت داشت، از آن‌ها پیروی کنید.';

  @override
  String wayfindingAboutMinutes(int minutes) {
    return 'حدود $minutes دقیقه';
  }

  @override
  String wayfindingApproxMetres(int metres) {
    return '~$metres متر';
  }

  @override
  String get wayfindingStepFreeUnknown =>
      'بدون‌پله بودن این مسیر هنوز تأیید نشده است. اگر به مسیر بدون پله نیاز دارید، از یکی از باجه‌های اطلاعات بپرسید.';

  @override
  String get locateShow => 'موقعیت من';

  @override
  String get locateFollow => 'دنبال‌کردن موقعیت من';

  @override
  String get locateStopFollowing => 'توقف دنبال‌کردن موقعیت';

  @override
  String get locateLowAccuracy => 'دقت موقعیت پایین است';

  @override
  String get locateUnavailable => 'موقعیت در دسترس نیست';

  @override
  String get locateServiceOff => 'روشن‌کردن سرویس موقعیت';

  @override
  String get mapLowAccuracy => 'دقت موقعیت پایین است';

  @override
  String mapOffCampus(String km) {
    return 'حدود $km کیلومتر با پردیس فاصله دارید';
  }

  @override
  String get mapLocatingOnCampus => 'در حال یافتن موقعیت شما روی نقشه…';

  @override
  String get pointMeTitle => 'مسیر را نشانم بده';

  @override
  String pointMeDistanceMeters(int meters) {
    return '$meters متر';
  }

  @override
  String pointMeDistanceKm(String km) {
    return '$km کیلومتر';
  }

  @override
  String get pointMeFindingNorth => 'در حال یافتن شمال…';

  @override
  String get pointMeNearby => 'تقریباً رسیدی';

  @override
  String get pointMeNoCompass =>
      'فلش زنده به گوشی با حسگر قطب‌نما نیاز دارد. جهت و فاصله در اینجاست.';

  @override
  String get pointMeImprovingAccuracy =>
      'موقعیت شما اکنون کمی نادقیق است — جهت تقریبی این است و با تثبیت GPS دقیق‌تر می‌شود.';

  @override
  String get pointMeNeedsLocation =>
      'برای نشان‌دادن مسیر، موقعیت مکانی را روشن کنید';

  @override
  String get pointMeUnknownPlace => 'آن مکان را پیدا نمی‌کنیم';

  @override
  String pointMeBearingSentence(
    String venue,
    String distance,
    String cardinal,
  ) {
    return '$venue حدوداً $distance در $cardinal شماست';
  }

  @override
  String pointMeA11yDirection(String venue, String side, String distance) {
    return '$venue $side، در فاصلهٔ $distance';
  }

  @override
  String get sideAhead => 'پیش روی شما';

  @override
  String get sideBehind => 'پشت سر شما';

  @override
  String get sideLeft => 'سمت چپ شما';

  @override
  String get sideRight => 'سمت راست شما';

  @override
  String get cardinalN => 'شمال';

  @override
  String get cardinalNE => 'شمال‌شرق';

  @override
  String get cardinalE => 'شرق';

  @override
  String get cardinalSE => 'جنوب‌شرق';

  @override
  String get cardinalS => 'جنوب';

  @override
  String get cardinalSW => 'جنوب‌غرب';

  @override
  String get cardinalW => 'غرب';

  @override
  String get cardinalNW => 'شمال‌غرب';

  @override
  String get mapNavGoogle => 'مسیریابی با نقشهٔ گوگل';

  @override
  String get mapNavOpenExternal => 'باز کردن در نقشهٔ گوگل';

  @override
  String get mapNavOpenExternalFailed => 'باز کردن نقشهٔ گوگل ممکن نشد.';

  @override
  String get mapPlaceListOnly => 'فقط جزئیات — روی نقشه نشان داده نمی‌شود';

  @override
  String mapNavDistanceMeters(int meters) {
    return '$meters متر';
  }

  @override
  String mapNavDistanceKm(String km) {
    return '$km کیلومتر';
  }

  @override
  String mapNavEtaMin(int mins) {
    return '$mins دقیقه';
  }

  @override
  String mapNavEtaHourMin(int hours, int mins) {
    return '$hours ساعت $mins دقیقه';
  }

  @override
  String get mapNavNoRoute => 'مسیر پیاده‌روی به اینجا پیدا نشد.';

  @override
  String get mapNavOffline => 'آفلاین هستید — دریافت مسیر ممکن نیست.';

  @override
  String get mapNavError => 'بارگیری مسیر ممکن نشد. دوباره تلاش کنید.';

  @override
  String get mapNavNeedLocation =>
      'برای دریافت مسیر پیاده‌روی، موقعیت مکانی را روشن کنید.';

  @override
  String get mapNavUnavailable => 'مسیریابی گوگل در این نسخه در دسترس نیست.';

  @override
  String get mapNavRetry => 'تلاش دوباره';

  @override
  String get mapNavWalkingWarning =>
      'مسیرهای پیاده‌روی آزمایشی‌اند — ممکن است پیاده‌رو یا مسیر مشخصی نداشته باشند؛ با احتیاط حرکت کنید.';

  @override
  String get mapNavWarningsTitle => 'نکات مسیر';

  @override
  String get mapNavDisclosureTitle =>
      'برای مسیریابی از نقشهٔ گوگل استفاده شود؟';

  @override
  String get mapNavDisclosureBody =>
      'برای نمایش مسیر پیاده‌روی، موقعیت فعلی شما به نقشهٔ گوگل ارسال می‌شود. در غیر این صورت موقعیت شما روی دستگاه می‌ماند و به اشتراک گذاشته نمی‌شود.';

  @override
  String get mapNavDisclosureAccept => 'استفاده از نقشهٔ گوگل';

  @override
  String get wayfindingMapUnavailable =>
      'نقشه نمایش داده نمی‌شود. راهنمای نوشتاری زیر به‌تنهایی کامل است.';

  @override
  String get settingsEraseTitle => 'حذف داده‌های من';

  @override
  String get settingsEraseBody =>
      'مهرهای پاسپورت، علاقه‌مندی‌ها و انتخاب شما دربارهٔ نقشهٔ گوگل را پاک می‌کند. تنظیمات زبان و پوستهٔ شما حفظ می‌شود.';

  @override
  String get settingsEraseConfirmTitle =>
      'داده‌های ذخیره‌شده روی این دستگاه حذف شوند؟';

  @override
  String get settingsEraseConfirmBody =>
      'این کار داده‌هایی را که این برنامه روی این دستگاه ذخیره کرده برای همیشه حذف می‌کند. آنچه پیش‌تر به گوگل ارسال شده قابل بازگرداندن نیست.';

  @override
  String get settingsEraseConfirmAction => 'حذف';

  @override
  String get settingsEraseCancel => 'انصراف';

  @override
  String get settingsEraseDone => 'حذف شد.';

  @override
  String get settingsEraseFailed =>
      'حذف داده‌های شما ممکن نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get mapDisplayDisclosureTitle => 'نقشهٔ گوگل در اینجا بارگذاری شود؟';

  @override
  String get mapDisplayDisclosureBody =>
      'این صفحه مسیر پیاده‌روی شما را روی نقشهٔ گوگل رسم می‌کند. گوگل درخواست نقشه و اطلاعات فنی درخواست و دستگاه لازم برای ارائهٔ آن را دریافت می‌کند. این صفحه از موقعیت مکانی شما استفاده نمی‌کند.\n\nهمین انتخاب، مسیریابی پیاده در بخش‌های دیگر برنامه را هم در بر می‌گیرد — اگر آن را بخواهید، موقعیت شما به گوگل ارسال می‌شود.';

  @override
  String get mapNavDisclosureDecline => 'الان نه';

  @override
  String get settingsRevokeGoogleConsent => 'لغو دسترسی نقشهٔ گوگل';

  @override
  String get settingsGoogleMapsNotice =>
      'هنگام استفاده از مسیریابی نقشهٔ گوگل، موقعیت شما به گوگل ارسال می‌شود. شرایط و سیاست حریم خصوصی گوگل اعمال می‌شود.';

  @override
  String get mapModeMap => 'نقشه';

  @override
  String get mapModePanorama => '۳۶۰°';

  @override
  String get mapModeCompass => 'قطب‌نما';

  @override
  String get compassFindingNorth => 'در حال یافتن شمال…';

  @override
  String get compassFindingYourLocation => 'در حال یافتن موقعیت شما…';

  @override
  String get compassUnavailable => 'قطب‌نما روی این دستگاه در دسترس نیست';

  @override
  String get compassUnavailableBody =>
      'در عوض مکان‌های نزدیک به همراه جهت نشان داده می‌شود.';

  @override
  String get compassNearbyTitle => 'نزدیک شما';

  @override
  String get compassFilterHint => 'فیلتر مکان‌ها';

  @override
  String get compassNothingNearby => 'هنوز جایی برای نشان‌دادن نزدیک نیست.';

  @override
  String get compassLocationNeeded =>
      'برای مسیریابی، موقعیت مکانی را روشن کنید';

  @override
  String get compassEnableLocation => 'روشن‌کردن موقعیت مکانی';

  @override
  String get compassYouAreHere => 'تقریباً رسیده‌اید';

  @override
  String get compassApproximate => 'موقعیت تقریبی';

  @override
  String get compassUnlocatable => 'موقعیت نامشخص — نقشهٔ چاپی را ببینید';

  @override
  String get homeNothingRunningNow =>
      'در این لحظه چیزی در حال اجرا نیست — برنامهٔ بعدی را ببینید.';

  @override
  String get homeFactColdTitle => 'هوا سرد و تاریک می‌شود';

  @override
  String get homeFactColdBody =>
      'کاپشن و چراغ‌قوه همراه داشته باشید. نزدیک تلسکوپ‌ها حالت نور سرخ بهترین است — دید شبانهٔ همه را حفظ می‌کند.';

  @override
  String get homeFactBookingTitle => 'بعضی نمایش‌ها نیازمند رزرو پیشین‌اند';

  @override
  String get homeFactBookingBody =>
      'برای نمایش‌های شعبده و «سفر به ماه» باید صندلی را هنگام خرید بلیت رزرو کنید.';

  @override
  String get homeFactParkingTitle => 'پارکینگ رایگان';

  @override
  String get homeFactParkingBody => 'West 5، West 6 و South 2.';

  @override
  String get homeFactMetroTitle => 'مترو';

  @override
  String get homeFactMetroBody =>
      'ایستگاه مترو Macquarie University حدود ۱۰ دقیقه پیاده از حیاط مرکزی فاصله دارد.';

  @override
  String get programClearSearch => 'پاک کردن جست‌وجو';

  @override
  String get programBookedOnly => 'فقط رزروشده';

  @override
  String get detailNotFoundTitle => 'پیدا نشد';

  @override
  String get detailSessionTimes => 'زمان سانس‌ها';

  @override
  String get detailTime => 'زمان';

  @override
  String get detailLocation => 'مکان';

  @override
  String get detailUnpublishedTimes =>
      'این زمان‌ها در برنامهٔ رسمی منتشر نشده‌اند — آن‌ها را تقریبی در نظر بگیرید.';

  @override
  String get detailPositionUnconfirmed =>
      'موقعیت دقیق این مکان هنوز نهایی نشده است. تابلوها را دنبال کنید و از باجهٔ اطلاعات بپرسید.';

  @override
  String get detail360View => 'نمای ۳۶۰ درجه';

  @override
  String detailMarkedOnMap(String letter) {
    return 'روی نقشهٔ چاپی رویداد با $letter نشان داده شده است';
  }

  @override
  String get myNightClearConfirm => 'پاک کردن';

  @override
  String get settingsTextSizeCardTitle =>
      'اندازهٔ متن را در گوشی خود تنظیم کنید';

  @override
  String get settingsPrivacyCardTitle =>
      'این برنامه چه چیزی را به اشتراک می‌گذارد';

  @override
  String get settingsMapDataAttribution =>
      'نقشهٔ پردیس: دانشگاه مکواری. مسیریابی پیاده و نقشه‌ای که روی آن نمایش داده می‌شود توسط گوگل ارائه می‌گردد.';

  @override
  String get infoFirstAid => 'کمک‌های اولیه';

  @override
  String get infoToilets => 'سرویس بهداشتی';

  @override
  String get infoRegistrationAndInfo => 'پذیرش و اطلاعات';

  @override
  String get infoFoodAndDrink => 'خوراکی و نوشیدنی';

  @override
  String get infoParking => 'پارکینگ';

  @override
  String get infoParkingFree => 'پارکینگ رایگان رویداد';

  @override
  String get infoWalkingFromParking => 'مسیر پیاده از پارکینگ';

  @override
  String get infoGettingHere => 'رسیدن به محل';

  @override
  String get infoBeforeYouCome => 'پیش از آمدن';

  @override
  String get infoDressTitle => 'لباس مناسب ایستادن در بیرون';

  @override
  String get infoDressBody =>
      'پارک تلسکوپ و حیاط مرکزی فضای باز هستند و شب‌های سپتامبر سرد می‌شود. کاپشن همراه داشته باشید.';

  @override
  String get infoTorchTitle => 'چراغ‌قوه بیاورید — اگر دارید، نور سرخ';

  @override
  String get infoTorchBody =>
      'به‌سمت رصدخانه واقعاً تاریک می‌شود و این عمدی است. نور سفید دید شبانهٔ اطرافیان را از بین می‌برد؛ نزدیک تلسکوپ‌ها از حالت نور سرخ استفاده کنید و روشنایی گوشی را کم کنید.';

  @override
  String get infoBookTitle => 'نمایش‌های بلیتی را زودتر رزرو کنید';

  @override
  String get infoBookBody =>
      'برای نمایش‌های شعبدهٔ فیزیک و شیمی و «سفر به ماه» باید صندلی را هنگام خرید بلیت رزرو کنید.';

  @override
  String get infoChildrenTitle => 'کودکان باید همراه بزرگسال باشند';

  @override
  String get infoChildrenBody =>
      'کودکان باید همیشه در فضای کودکان همراه پدر، مادر یا سرپرست باشند.';

  @override
  String get infoCloudTitle => 'اگر هوا ابری شد';

  @override
  String get infoCloudBody =>
      'رصد با تلسکوپ به هوا بستگی دارد، اما سانس‌های آسمان‌نما در مرکز ورزش و آبی در هر حال برگزار می‌شوند.';

  @override
  String get infoCredits => 'اعتبارها';

  @override
  String get previewSection => 'پیش‌نمایش';

  @override
  String get previewTitle => 'پیش‌نمایش شب رویداد';

  @override
  String previewBody(String date) {
    return 'ساعت برنامه را روی هر لحظه از $date تنظیم کنید تا ببینید برنامه در آن لحظه چگونه است. پیش از شب رویداد سودمند است؛ در طول رویداد خاموش بگذارید.';
  }

  @override
  String get previewChooseTime => 'انتخاب زمان';

  @override
  String get previewBackToRealTime => 'بازگشت به زمان واقعی';

  @override
  String previewBanner(String time) {
    return 'پیش‌نمایش $time در شب رویداد';
  }

  @override
  String get previewExit => 'خروج';

  @override
  String get passportTitle => 'گذرنامهٔ نجوم';

  @override
  String get venueNoDirections =>
      'هنوز راهنمای نوشتاری برای رسیدن به اینجا نداریم. از باجهٔ اطلاعات در حیاط مرکزی بپرسید.';

  @override
  String get venueNothingScheduled => 'امشب برنامه‌ای در اینجا نیست.';

  @override
  String get parkingNoConfirmedPosition =>
      'هنوز موقعیت تأییدشده‌ای برای این پارکینگ نداریم — تابلوهای محل را دنبال کنید.';

  @override
  String creditsEventMaterialsBody(String host, String faculty, String cricos) {
    return 'مواد رویداد، نقشهٔ پردیس و نشان‌ها © $host، $faculty. $cricos.';
  }

  @override
  String creditsHeroImageBody(String credit) {
    return 'تصویر اصلی: «$credit». با اجازه برای این پروژه استفاده شده است.';
  }

  @override
  String get wayfindingReset => 'بازنشانی';

  @override
  String get wayfindingNoPairTitle => 'هنوز مسیری برای این دو نقطه نداریم';

  @override
  String get wayfindingNoPairBody =>
      'مسیر نوشته‌شده‌ای میان این دو نقطه نداریم. می‌توانید حیاط مرکزی را نقطهٔ واسط بگیرید — بیشتر مسیرها از آن می‌گذرند — یا از یکی از باجه‌های اطلاعات بپرسید.';

  @override
  String get wayfindingDraftRoute =>
      'این راهنما پیش‌نویس است و هنوز شب‌هنگام در دانشگاه پیموده و بازبینی نشده است. اگر با تابلوها و راهنمایان رویداد تفاوت داشت، از آن‌ها پیروی کنید.';

  @override
  String get wayfindingStepFree => 'این مسیر بدون پله است.';

  @override
  String get wayfindingNotStepFree => 'این مسیر بدون پله نیست.';

  @override
  String get settingsLanguageSystemHint =>
      'اگر زبان دستگاه شما در دسترس نباشد، انگلیسی نمایش داده می‌شود.';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguagePersian => 'فارسی';

  @override
  String get creditsMapDataBody =>
      'نقشهٔ پردیس: دانشگاه مکواری. مسیریابی پیاده و نقشه‌ای که روی آن نمایش داده می‌شود توسط گوگل ارائه می‌گردد.';

  @override
  String eventSourceNote(String note) {
    return 'منبع: $note';
  }

  @override
  String eventMapReference(String ref) {
    return 'با نشان $ref روی نقشهٔ چاپی رویداد';
  }

  @override
  String get timingOnTheNight => 'در شب رویداد';

  @override
  String get categoryActivities => 'فعالیت‌ها';

  @override
  String get categoryShortTalks => 'سخنرانی‌های کوتاه';

  @override
  String get categoryKeynote => 'سخنرانی کلیدی';

  @override
  String get categoryFeaturedPresentations => 'ارائه‌های ویژه';

  @override
  String get bandEarlyEvening => '۴ تا ۶ بعدازظهر';

  @override
  String get bandEvening => '۶ تا ۸ شب';

  @override
  String get bandLateEvening => '۸ تا ۱۰ شب';
}
