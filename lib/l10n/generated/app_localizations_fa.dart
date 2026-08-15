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
    return '$count مورد در برنامه';
  }

  @override
  String programFilteredCount(int shown, int total) {
    return '$shown از $total نمایش داده شد';
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
  String get mapAttribution => '© مشارکت‌کنندگان OpenStreetMap';

  @override
  String get mapRecentre => 'بازگشت به مرکز';

  @override
  String get mapZoomIn => 'بزرگ‌نمایی';

  @override
  String get mapZoomOut => 'کوچک‌نمایی';

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
  String get settingsLanguageSystem => 'مطابق تنظیمات گوشی';

  @override
  String settingsAbout(String eventName) {
    return 'دربارهٔ $eventName';
  }

  @override
  String get settingsPrivacy => 'حریم خصوصی';

  @override
  String get settingsPrivacyTitle => 'هیچ داده‌ای از گوشی شما خارج نمی‌شود';

  @override
  String get settingsPrivacyBody =>
      'نه حسابی وجود دارد و نه ورودی. فعالیت‌های ذخیره‌شدهٔ شما فقط روی همین دستگاه نگهداری می‌شوند. این برنامه هیچ داده‌ٔ تحلیلی جمع نمی‌کند و موقعیت مکانی شما را دنبال نمی‌کند.\n\nتنها چیزی که از اینترنت دریافت می‌شود، تصاویر نقشه است.';

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
  String get wayfindingStartingFrom => 'مبدأ';

  @override
  String get wayfindingGoingTo => 'مقصد';

  @override
  String get wayfindingPickTitle => 'مبدأ و مقصد را انتخاب کنید';

  @override
  String get wayfindingPickBody =>
      'جایی که پارک کرده‌اید و مقصدتان را انتخاب کنید تا راهنمای نوشتاری برای پیاده‌روی در تاریکی به شما بدهیم.';

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
      'دسترسی بدون پله در این مسیر هنوز تأیید نشده است. اگر به مسیر بدون پله نیاز دارید، از باجهٔ اطلاعات بپرسید.';

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
}
