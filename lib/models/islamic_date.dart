import 'package:hijri/hijri_calendar.dart';

class IslamicDate {
  final HijriCalendar hijri;

  IslamicDate(DateTime gregorianDate) : hijri = HijriCalendar.fromDate(gregorianDate);

  String get formattedDate {
    return '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear}';
  }

  String get shortFormattedDate {
    return '${hijri.hDay}/${hijri.hMonth}/${hijri.hYear}';
  }

  @override
  String toString() {
    return formattedDate;
  }
}