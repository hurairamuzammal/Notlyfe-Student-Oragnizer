import 'dart:ui' as ui;

import 'package:animated_analog_clock/animated_analog_clock.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:notlyfe/enums/hijri_months.dart';

class ClockScreen extends StatelessWidget {
  const ClockScreen({super.key});

  String convertToArabicNumbers(String input) {
    const westernDigits = '0123456789';
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    return input.split('').map((char) {
      final index = westernDigits.indexOf(char);
      return index == -1 ? char : arabicDigits[index];
    }).join('');
  }

  String getFormattedGregorianDate() {
    return DateFormat('dd MMMM yyyy', 'en').format(DateTime.now());
  }

  Widget getGregorianDate(BuildContext context) {
    return Text(
      getFormattedGregorianDate(),
      style: GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget getHijriDate(BuildContext context) {
    final hijri = HijriCalendar.now();
    final day = convertToArabicNumbers(hijri.hDay.toString());
    final year = convertToArabicNumbers(hijri.hYear.toString());
    final monthIndex = (hijri.hMonth - 1).clamp(0, hijriMonthNames.length - 1);
    final monthName = hijriMonthNames[monthIndex];

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$day $monthName، $year',
          style: GoogleFonts.elMessiri(
            fontSize: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget getWidget(double width, BuildContext context) {
    if (width > 600) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: AnimatedAnalogClock(
                size: width / 4,
                showSecondHand: true,
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                dialType: DialType.numberAndDashes,
                hourDashColor: Theme.of(context).colorScheme.primary,
                
                minuteDashColor: Theme.of(context).colorScheme.primary,
                numberColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.all(15),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              // color: Theme.of(context).colorScheme.primaryFixedDim,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getGregorianDate(context),
                    const SizedBox(height: 90),
                    getHijriDate(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            AnimatedAnalogClock(
              size: width / 2,
              showSecondHand: true,
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
              dialType: DialType.numberAndDashes,
              hourDashColor: Theme.of(context).colorScheme.primary,
              minuteDashColor: Theme.of(context).colorScheme.primary,
              numberColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 30),
            getGregorianDate(context),
            const SizedBox(height: 20),
            getHijriDate(context),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clock Screen'),
        centerTitle: true,
      ),
      body: getWidget(deviceWidth, context),
    );
  }
}
