import 'package:animated_analog_clock/animated_analog_clock.dart';
import 'package:flutter/material.dart';
import 'package:notlyfe/data/shortcut_data.dart';
import 'dart:math';

import 'package:notlyfe/screens/clock_screen.dart';

class ClockShortcutWidget extends StatelessWidget {
  const ClockShortcutWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeDevice = deviceWidth > 600;
    final bool isWiderScreen = deviceWidth > 1000;

    // Fixed height for consistency
    const double containerHeight = 180.0;

    // Calculate total icons based on available space
    int totalIcons = deviceWidth < 600 ? 4 : 6;

    final double clockSize = isLargeDevice
        ? min(160.0, deviceWidth * 0.2)
        : min(150.0, deviceWidth * 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: EdgeInsets.all(isLargeDevice ? 8.0 : 4.0),
          child: SizedBox(
            height: containerHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Shortcuts centered
                Expanded(
                  flex: isWiderScreen ? 2 : 3,
                  child: Center(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(4.0),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 85,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      itemCount: totalIcons,
                      itemBuilder: (context, index) {
                        return Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        shortcuts[index].route),
                              );
                            },
                            child: Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.95),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  shortcuts[index].icon,
                                  size: isLargeDevice ? 30.0 : 45.0,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Clock centered
                Expanded(
                  flex: isWiderScreen ? 2 : 3,
                  child: Align(
                    alignment: Alignment.center,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onLongPress: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const ClockScreen()));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 0.0,
                          ),
                        ),
                        child: AnimatedAnalogClock(
                          showSecondHand: true,
                          backgroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          dialType: DialType.numberAndDashes,
                          size: clockSize,
                          hourDashColor: Theme.of(context).colorScheme.primary,
                          minuteDashColor:
                              Theme.of(context).colorScheme.primary,
                          numberColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
